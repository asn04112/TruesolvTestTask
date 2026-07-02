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
import checkout from '@salesforce/apex/ItemService.checkout';

const ACCOUNT_FIELDS = [ACCOUNT_NAME_FIELD, ACCOUNT_NUMBER_FIELD, ACCOUNT_INDUSTRY_FIELD];

export default class ItemPurchaseTool extends NavigationMixin(LightningElement) {
    @track selectedFamily = '';
    @track selectedType = '';
    @track searchTerm = '';
    @track selectedItem;

    accountId;
    isManager = true;
    @track cartItems = [];            
    @track filteredItems = [];
    @track allItems = [];
    @track familyOptions = [];
    @track typeOptions = [];
    @track showCartModal = false;
    @track showDetailModal = false;
    @track showCreateModal = false;
    @track selectedItemId;

    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    account;

      @wire(getRecord, { recordId: USER_ID, fields: [USER_ISMANAGER_FIELD] })
      user({ data, error }) {
          if (data) {
              this.isManager = getFieldValue(data, USER_ISMANAGER_FIELD) || false;
          }
      }

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        this.accountId = urlParams.get('c__accountId') || '';
        this.refreshItems();

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

    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: TYPE_FIELD })
    typePicklist({ data, error }) {
        if (data) {
            this.typeOptions = this.buildOptions(data.values);
        } else if (error) {
            console.error('Error loading Type picklist', error);
        }
    }

    buildOptions(picklistValues) {
        const options = [{ label: 'All', value: '' }];
        picklistValues.forEach(plValue => {
            options.push({ label: plValue.label, value: plValue.value });
        });
        return options;
    }

    async refreshItems(family, type, searchTerm) {
        try {
            const data = await getItems({ family: family || '', type: type || '', searchTerm: searchTerm || '' });
            this.allItems = data || [];
            this.filteredItems = [...this.allItems]; // bypass applyFilters for testing
        } catch (error) {
            console.error("Apex error:", error);
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
        if (event.target.name === 'family') {
            this.selectedFamily = event.detail.value;
        } else if (event.target.name === 'type') {
            this.selectedType = event.detail.value;
        }
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
    this.searchTerm = event.target.value;
    this.refreshItems(this.selectedFamily, this.selectedType, this.searchTerm);
    }

    handleShowDetails(event) {
        this.selectedItem = event.detail;  
        this.showDetailModal = true;
    }

    closeDetailModal() {
        this.showDetailModal = false;
        this.selectedItem = null;
    }

    handleDetails(event) {
        const itemId = event.currentTarget.dataset.itemId;
        const item = this.allItems.find(i => i.Id === itemId);
        if (item) {
            this.selectedItem = item;
            this.showDetailModal = true;
        } else {
        }
    }

    handleAdd(event) {
        const itemId = event.currentTarget.dataset.itemId;
        const item = this.allItems.find(i => i.Id === itemId);
        
        if (!item) return;

        if (!item.AvailableQuantity__c || item.AvailableQuantity__c <= 0) {
            this.showToast('Out of stock', `${item.Name} is currently unavailable.`, 'error');
            return;
    }

    const existing = this.cartItems.find(ci => ci.itemId === itemId);
    if (!existing) 
        this.cartItems = [...this.cartItems, {
            itemId: item.Id,
            name: item.Name,
            price: item.Price__c,
            unitCost: item.Price__c,   
            availableQuantity: item.AvailableQuantity__c,
            quantity: 1
        }];
    

    this.showToast('Success', `${item.Name} added to cart`, 'success');
    }

    openCartModal() {
        this.showCartModal = true;
    }

    closeCartModal() {
        this.showCartModal = false;
    }


    async handleCheckout() {
        try {
            // Prepare cart items for Apex
            const cartData = this.cartItems.map(ci => ({
                itemId: ci.itemId,
                quantity: ci.quantity,
                unitCost: ci.unitCost
            }));
            console.log('Checkout data:', JSON.stringify(cartData));
            console.log('AccountId:', this.accountId);
            console.log('cartData:', JSON.stringify(cartData));

            const purchaseId = await checkout({ accountId: this.accountId, cartItems: cartData });
            
            this.showToast('Success', 'Purchase created!', 'success');
            this.showCartModal = false;
            this.cartItems = []; // clear cart

            // Redirect to the Purchase record
            // Using NavigationMixin or window.open
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: purchaseId,
                    objectApiName: 'Purchase__c',
                    actionName: 'view'
                }
            });
            // Alternative: window.open('/' + purchaseId, '_self');
        } catch (error) {
            console.error('Checkout error:', error);
            console.error('Error body:', JSON.stringify(error.body));
            this.showToast('Error', error.body?.message || 'Checkout failed', 'error');
        }
    }
    handleQuantityChange(event) {
        const { itemId, quantity } = event.detail;
        // Find and update quantity in cartItems immutably
        this.cartItems = this.cartItems.map(ci => 
            ci.itemId === itemId ? { ...ci, quantity: quantity } : ci
        );
    }

    handleRemoveItem(event) {
        const { itemId } = event.detail;
        this.cartItems = this.cartItems.filter(ci => ci.itemId !== itemId);
    }
}