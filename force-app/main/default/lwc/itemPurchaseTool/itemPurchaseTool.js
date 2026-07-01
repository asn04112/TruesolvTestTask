import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_NUMBER_FIELD from '@salesforce/schema/Account.AccountNumber';
import ACCOUNT_INDUSTRY_FIELD from '@salesforce/schema/Account.Industry';
import USER_ISMANAGER_FIELD from '@salesforce/schema/User.IsManager__c';
import USER_ID from '@salesforce/user/Id';

const ACCOUNT_FIELDS = [ACCOUNT_NAME_FIELD, ACCOUNT_NUMBER_FIELD, ACCOUNT_INDUSTRY_FIELD];

export default class ItemPurchaseTool extends NavigationMixin(LightningElement) {
    accountId;
    isManager = false;

    // Wire account from page parameter
    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    account;

        connectedCallback() {
        // Extract accountId from URL parameter "c__accountId"
        const urlParams = new URLSearchParams(window.location.search);
        this.accountId = urlParams.get('c__accountId') || '';

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
}