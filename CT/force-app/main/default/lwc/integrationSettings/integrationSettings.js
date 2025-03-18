import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getConfigurations from '@salesforce/apex/IntegrationConfigController.getConfigurations';
import saveConfiguration from '@salesforce/apex/IntegrationConfigController.saveConfiguration';
import deleteConfiguration from '@salesforce/apex/IntegrationConfigController.deleteConfiguration';

export default class IntegrationSettings extends NavigationMixin(LightningElement) {
    @track connection = {
        region: '',
        name: '',
        accountId: '',
        passcode: '',
        developerName: ''
    };

    @track connections = [];
    @track isLoading = false;
    wiredConfigResult;
    
    // Add these new track properties
    @track showSettingsView = true;
    @track showSyncListView = false;
    @track selectedConnectionId;
    @track selectedConnectionName;
    
    regionOptions = [
        { label: 'India', value: 'IN' },
        { label: 'United States', value: 'US' },
        { label: 'Europe', value: 'EU' }
    ];

    showNewConnectionModal = false;
    isEditing = false;

    @wire(getConfigurations)
    wiredConfig(result) {
        this.wiredConfigResult = result;
        const { data, error } = result;
        
        if (data) {
            console.log('Fetched configurations:', data);
            this.connections = data.map(conn => ({
                id: conn.Id,
                developerName: conn.Name, // Use Name instead of DeveloperName
                name: conn.Name,
                region: conn.Region__c,
                accountId: conn.CleverTap_Account_ID__c,
                passcode: conn.CleverTap_Passcode__c
            }));
        } else if (error) {
            console.error('Error fetching configurations:', error);
            this.showToast('Error', 'Failed to fetch configurations', 'error');
        }
    }
    

    get modalTitle() {
        return this.isEditing ? 'Edit Connection' : 'New Connection';
    }

    handleAddNewConnection() {
        this.isEditing = false;
        this.connection = {
            region: '',
            name: '',
            accountId: '',
            passcode: '',
            developerName: ''
        };
        this.showNewConnectionModal = true;
    }

    handleRegionChange(event) {
        this.connection.region = event.detail.value;
    }

    handleNameChange(event) {
        this.connection.name = event.detail.value;
    }

    handleAccountIdChange(event) {
        this.connection.accountId = event.detail.value;
    }

    handlePasscodeChange(event) {
        this.connection.passcode = event.detail.value;
    }

    // Modified to use conditional rendering instead of navigation
    handleMapField(event) {
        const connId = event.currentTarget.dataset.id;
        const selectedConn = this.connections.find(conn => conn.id === connId);
        
        if (selectedConn) {
            this.selectedConnectionId = connId;
            this.selectedConnectionName = selectedConn.name;
            
            // Toggle views instead of navigating
            this.showSettingsView = false;
            this.showSyncListView = true;
        } else {
            this.showToast('Error', 'Connection identifier not found', 'error');
        }
    }

    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        const conn = this.connections.find(c => c.id === id);
        
        if (conn) {
            this.connection = { ...conn };
            this.isEditing = true;
            this.showNewConnectionModal = true;
        }
    }

    async handleDelete(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        
        if (!id) {
            this.showToast('Error', 'Configuration identifier not found', 'error');
            return;
        }
    
        if (confirm(`Are you sure you want to delete the connection "${name}"?`)) {
            try {
                this.isLoading = true;
                this.showToast('Info', 'Starting deletion process...', 'info');
                
                const result = await deleteConfiguration({ configId: id });
                
                if (result === 'Success') {
                    this.showToast('Success', 'Configuration deleted successfully', 'success');
                    await refreshApex(this.wiredConfigResult);
                } else {
                    throw new Error('Failed to process deletion');
                }
            } catch (error) {
                console.error('Error during deletion:', error);
                this.showToast('Error', error.body?.message || 'Failed to delete configuration', 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    async handleSave() {
        if (this.validateForm()) {
            try {
                this.isLoading = true;
                const result = await saveConfiguration({ config: this.connection });
                
                if (result === 'Success') {
                    this.showNewConnectionModal = false;
                    this.showToast('Success', 'Configuration saved successfully', 'success');
                    
                    // Add a delay before refreshing to allow metadata deployment to complete
                    this.showToast('Info', 'Waiting for changes to process...', 'info');
                    await this.refreshAfterDelay(10000);
                    this.showToast('Success', 'Configuration refresh completed', 'success');
                } else {
                    this.showToast('Error', 'Failed to save configuration', 'error');
                }
            } catch (error) {
                console.error('Error saving configuration:', error);
                this.showToast('Error', error.body?.message || 'Failed to save configuration', 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    // Add method to handle returning from sync list view
    handleReturnToSettings() {
        this.showSettingsView = true;
        this.showSyncListView = false;
    }

    async refreshAfterDelay(timeInMilliseconds) {
        await new Promise(resolve => setTimeout(resolve, timeInMilliseconds));
        await refreshApex(this.wiredConfigResult);
    }

    validateForm() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);
        return allValid;
    }

    handleCancel() {
        this.showNewConnectionModal = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}