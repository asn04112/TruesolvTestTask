import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateItemModal extends LightningElement {

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSuccess(event) {
        // The record-edit-form fires 'success' with detail containing the new record's ID
        const newItemId = event.detail.id;
        // Fire an event so the parent can close the modal and refresh the item list
        this.dispatchEvent(new CustomEvent('itemcreated', {
            detail: newItemId
        }));
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