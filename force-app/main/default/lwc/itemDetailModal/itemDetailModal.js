import { LightningElement, api } from 'lwc';

export default class ItemDetailModal extends LightningElement {
    @api item;

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

}