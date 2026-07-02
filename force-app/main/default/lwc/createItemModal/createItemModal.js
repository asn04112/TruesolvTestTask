import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createItem from '@salesforce/apex/ItemService.createItem';  // <-- add this

export default class CreateItemModal extends LightningElement {

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        const itemName = fields.Name;
        const description = fields.Description__c;
        const type = fields.Type__c;
        const family = fields.Family__c;
        const price = fields.Price__c;
        const availableQty = fields.AvailableQuantity__c;

        createItem({
            name: itemName,
            description: description,
            type: type,
            family: family,
            price: price,
            availableQty: availableQty
        })
        .then(newItemId => {
            this.dispatchEvent(new CustomEvent('itemcreated', { detail: newItemId }));
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Item created',
                variant: 'success'
            }));
    })
    .catch(error => {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: error.body.message || 'Unknown error',
            variant: 'error'
        }));
    });
}
    handleError(event) {
        console.error('Form error:', JSON.stringify(event.detail));
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: event.detail?.output?.errors?.[0]?.message || 'Unknown error',
            variant: 'error'
        }));
    }
}