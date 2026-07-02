import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CartModal extends LightningElement {
    @api cartItems;

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    checkout() {
        this.dispatchEvent(new CustomEvent('checkout'));
    }

    get isCheckoutDisabled() {
        if (!this.cartItems || this.cartItems.length === 0) return true;
        return this.cartItems.some(ci => ci.quantity > ci.availableQuantity);
    }

    get grandTotal() {
        if (!this.cartItems) return 0;
        return this.cartItems.reduce((sum, ci) => sum + (ci.unitCost * ci.quantity), 0);
    }

    handleQuantityChange(event) {
        const itemId = event.currentTarget.dataset.itemId;
        const newValue = parseInt(event.detail.value, 10);
        const ci = this.cartItems.find(i => i.itemId === itemId);
        if (!ci) return;

        // Validate client-side bounds
        if (isNaN(newValue) || newValue < 1) {
            // Reset to 1, dispatch event
            this.dispatchQuantityChange(itemId, 1);
        } else if (newValue > ci.availableQuantity) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Stock limit',
                message: `Only ${ci.availableQuantity} units available for ${ci.name}`,
                variant: 'warning'
            }));
            this.dispatchQuantityChange(itemId, ci.availableQuantity);
        } else {
            this.dispatchQuantityChange(itemId, newValue);
        }
    }

    handleRemove(event) {
        const itemId = event.currentTarget.dataset.itemId;
        this.dispatchEvent(new CustomEvent('removeitem', {
            detail: { itemId }
        }));
    }

    dispatchQuantityChange(itemId, quantity) {
        this.dispatchEvent(new CustomEvent('quantitychange', {
            detail: { itemId, quantity }
        }));
    }
}