import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_NUMBER_FIELD from '@salesforce/schema/Account.AccountNumber';
import ACCOUNT_INDUSTRY_FIELD from '@salesforce/schema/Account.Industry';
import USER_ISMANAGER_FIELD from '@salesforce/schema/User.IsManager__c';
import USER_ID from '@salesforce/user/Id';
import getItems from '@salesforce/apex/ItemService.getItems';
import FAMILY_FIELD from '@salesforce/schema/Item__c.Family__c';
import TYPE_FIELD from '@salesforce/schema/Item__c.Type__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ITEM_OBJECT from '@salesforce/schema/Item__c';

const ACCOUNT_FIELDS = [ACCOUNT_NAME_FIELD, ACCOUNT_NUMBER_FIELD, ACCOUNT_INDUSTRY_FIELD];

export default class ItemPurchaseTool extends NavigationMixin(LightningElement) {
    @track selectedFamily = '';
@track selectedType = '';
@track searchTerm = '';

    accountId;
    isManager = true;
    @track cartItems = [];            
    @track filteredItems = [];
    @track allItems = [];
    @track familyOptions = [];
    @track typeOptions = [];
    @track showCartModal = false;
    @track showDetailsModal = false;
    @track showCreateModal = false;
    @track selectedItemId;

    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    account;

    // @wire(getRecord, { recordId: USER_ID, fields: [USER_ISMANAGER_FIELD] })
    // user({ data, error }) {
    //     if (data) {
    //          this.isManager = getFieldValue(data, USER_ISMANAGER_FIELD) || false;
    //     }
    // }

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        this.accountId = urlParams.get('c__accountId') || '';
        this.refreshItems();
        console.log("items:" + this.allItems)

    }

    get accountName() {
        return getFieldValue(this.account.data, ACCOUNT_NAME_FIELD);
    }
    get accountNumber() {
        return getFieldValue(this.account.data, ACCOUNT_NUMBER_FIELD);
    }
    get industry() {
        return getFieldValue(this.account.data, ACCOUNT_INDUSTRY_FIELD);
    }

    get cartItemCount() {
        return this.cartItems.reduce((sum, ci) => sum + ci.quantity, 0);
    }

@wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: FAMILY_FIELD })
    familyPicklist({ data, error }) {
        if (data) {
            this.familyOptions = this.buildOptions(data.values);
        } else if (error) {
            console.error('Error loading Family picklist', error);
        }
    }

    // Wire Type picklist values
    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: TYPE_FIELD })
    typePicklist({ data, error }) {
        if (data) {
            this.typeOptions = this.buildOptions(data.values);
        } else if (error) {
            console.error('Error loading Type picklist', error);
        }
    }

    // Helper to add "All" option and map values
    buildOptions(picklistValues) {
        const options = [{ label: 'All', value: '' }];
        picklistValues.forEach(plValue => {
            options.push({ label: plValue.label, value: plValue.value });
        });
        return options;
    }

    async refreshItems(family, type, searchTerm) {
        console.log("refreshing items with:", { family, type, searchTerm });
        try {
            const data = await getItems({ family: family || '', type: type || '', searchTerm: searchTerm || '' });
            console.log("Apex returned items count: " + (data ? data.length : 'null'));
            this.allItems = data || [];
            this.filteredItems = [...this.allItems]; // bypass applyFilters for testing
            console.log("filteredItems length: " + this.filteredItems.length);
        } catch (error) {
            console.error("Apex error:", error);
            // Optionally show a toast with the error message
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    applyFilters(family, type, searchTerm) {
        if (family) {
            this.filteredItems = this.filteredItems.filter(i => i.Family__c === family);
        }
        if (type) {
            this.filteredItems = this.filteredItems.filter(i => i.Type__c === type);
        }
        if (searchTerm) {
        const term = searchTerm.toLowerCase();
        this.filteredItems = this.filteredItems.filter(i =>
            i.Name.toLowerCase().includes(term) ||
            (i.Description__c && i.Description__c.toLowerCase().includes(term))
        );
    }
    }

handleFilterChange(event) {
    console.log('filter change fired', event.target.name, event.detail.value);
    if (event.target.name === 'family') {
        this.selectedFamily = event.detail.value;
    } else if (event.target.name === 'type') {
        this.selectedType = event.detail.value;
    }
    console.log('after update -> family:', this.selectedFamily, 'type:', this.selectedType);
    this.refreshItems(this.selectedFamily, this.selectedType, this.searchTerm);
}

    openCreateModal() { this.showCreateModal = true; }
    closeCreateModal() { this.showCreateModal = false; }
    handleItemCreated() {
        this.closeCreateModal();
        this.refreshItems();
        this.showToast('Success', 'Item created.', 'success');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    handleSearch(event) {
    console.log('handleSearch called, value:', event.target.value);
    this.searchTerm = event.target.value;
    this.refreshItems(this.selectedFamily, this.selectedType, this.searchTerm);
}
}