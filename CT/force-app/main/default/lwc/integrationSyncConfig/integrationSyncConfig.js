import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createSyncConfiguration from '@salesforce/apex/IntegrationSyncController.createSyncConfiguration';
import getSyncConfigurationById from '@salesforce/apex/IntegrationSyncController.getSyncConfigurationById';
import updateSyncConfiguration from '@salesforce/apex/IntegrationSyncController.updateSyncConfiguration';

export default class IntegrationSyncConfig extends LightningElement {
    @api recordId;
    @api mode = 'new';
    @api objectName = 'CleverTap_Mapping__c';
    @api fieldName = 'Data_Type__c';
    @api connectionId;
    @api connectionName;
    
    @track picklistOptions = [];
    @track isLoading = false;
    @track syncData = {
        name: '',
        syncType: '',
        sourceEntity: '',
        targetEntity: '',
        status: 'Active', // default status for new configurations
        connectionId: ''
    };
    
    @track showBasicConfig = true;
    @track showFieldMapping = false;
    @track syncId;
    @track savedToDatabase = false;

    connectedCallback() {
        // Set the connection ID from the API property
        if (this.connectionId) {
            this.syncData.connectionId = this.connectionId;
        }
        
        if (this.mode === 'edit' && this.recordId) {
            this.syncId = this.recordId;
            this.savedToDatabase = true;
            this.loadSyncConfiguration();
        }
    }

    async loadSyncConfiguration() {
        if (!this.recordId) {
            return;
        }
        
        try {
            this.isLoading = true;
            
            const result = await getSyncConfigurationById({ syncId: this.recordId });
            
            if (result) {
                this.syncData = {
                    name: result.name || '',
                    syncType: result.syncType || '',
                    sourceEntity: result.sourceEntity || '',
                    targetEntity: result.targetEntity || '',
                    status: result.status || 'Inactive',
                    connectionId: this.syncData.connectionId // Preserve connection ID
                };
                
                // Force a re-render
                this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(element => {
                    if (element.name && this.syncData[element.name] !== undefined) {
                        setTimeout(() => {
                            element.value = this.syncData[element.name];
                        }, 0);
                    }
                });
                
                this.syncId = this.recordId;
            } else {
                this.showToast('Warning', 'No data found for this configuration', 'warning');
            }
        } catch (error) {
            this.showToast('Error', 'Error loading sync configuration: ' + (error.message || error.body?.message || 'Unknown error'), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get syncTypeOptions() {
        return [
            { label: 'Salesforce to CleverTap', value: 'salesforce_to_clevertap' }
        ];
    }

    get sourceEntityOptions() {
        return [
            { label: 'Contact', value: 'Contact' },
            { label: 'Lead', value: 'Lead' },
            { label: 'Account', value: 'Account' },
            { label: 'Opportunity', value: 'Opportunity' }
        ];
    }

    get targetEntityOptions() {
        return [
            { label: 'Profile', value: 'profile' },
            { label: 'Event', value: 'event' }
        ];
    }

    handleNameChange(event) {
        this.syncData.name = event.target.value;
    }

    handleSyncTypeChange(event) {
        this.syncData.syncType = event.target.value;
    }

    handleSourceEntityChange(event) {
        this.syncData.sourceEntity = event.target.value;
    }

    handleTargetEntityChange(event) {
        this.syncData.targetEntity = event.target.value;
    }

    // Modified to dispatch cancel event instead of navigating
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // Modified to dispatch cancel event instead of navigating
    handleBack() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // Modified to not save the configuration yet
    async handleNext() {
        if (this.validateForm()) {
            try {
                this.isLoading = true;
                
                // If we're in edit mode, the record already exists
                if (this.mode === 'edit') {
                    // For edit mode, we can update the configuration now
                    await updateSyncConfiguration({
                        syncId: this.recordId,
                        syncData: JSON.stringify(this.syncData)
                    });
                    this.syncId = this.recordId;
                    this.showToast('Success', 'Sync configuration updated successfully', 'success');
                    this.savedToDatabase = true;
                }
                
                // Just switch to the field mapping view without creating a new record
                this.showBasicConfig = false;
                this.showFieldMapping = true;

                const fieldMappingComponent = this.template.querySelector('c-integration-field-mapping');
                if (fieldMappingComponent) {
                    // Only provide syncId if it's already saved to the database (edit mode)
                    if (this.savedToDatabase) {
                        fieldMappingComponent.syncId = this.syncId;
                    }
                    // Pass the entity types for reference
                    fieldMappingComponent.sourceEntity = this.syncData.sourceEntity;
                    fieldMappingComponent.targetEntity = this.syncData.targetEntity;
                }
            } catch (error) {
                const action = this.mode === 'edit' ? 'update' : 'create';
                this.showToast('Error', `Failed to ${action} sync configuration: ${error.message || error.body?.message || 'Unknown error'}`, 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    validateForm() {
        const inputFields = this.template.querySelectorAll('lightning-input,lightning-combobox');
        let isValid = true;

        inputFields.forEach(field => {
            if (!field.checkValidity()) {
                field.reportValidity();
                isValid = false;
            }
        });

        if (isValid) {
            if (!this.syncData.name || !this.syncData.syncType || 
                !this.syncData.sourceEntity || !this.syncData.targetEntity) {
                this.showToast('Error', 'Please fill in all required fields', 'error');
                return false;
            }
        }

        return isValid;
    }
    
    // Modified to save the configuration first, then save field mappings
    async handleMappingSave() {
        try {
            this.isLoading = true;
            
            // First, save the basic configuration if it's not yet saved
            if (!this.savedToDatabase) {
                // Ensure status is set
                this.syncData.status = 'Active';
                
                // Save the configuration
                const result = await createSyncConfiguration({
                    syncData: JSON.stringify(this.syncData)
                });
                
                this.syncId = result;
                this.recordId = result;
                this.savedToDatabase = true;
            }
            
            // Get the field mapping component
            const fieldMappingComponent = this.template.querySelector('c-integration-field-mapping');
            if (fieldMappingComponent) {
                // Set the syncId first
                fieldMappingComponent.syncId = this.syncId;
                
                // Then call the explicit save method on the field mapping component
                await fieldMappingComponent.saveFieldMappings();
            }
            
            this.showToast('Success', 'Sync configuration and field mappings saved successfully', 'success');
            this.dispatchEvent(new CustomEvent('save'));
        } catch (error) {
            const action = this.mode === 'edit' ? 'update' : 'create';
            this.showToast('Error', `Failed to ${action} configuration: ${error.message || error.body?.message || 'Unknown error'}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Modified to handle complete cancellation
    handleMappingCancel() {
        // If this is a new sync and we haven't saved to the database,
        // we just return to the basic config screen
        if (!this.savedToDatabase) {
            this.showBasicConfig = true;
            this.showFieldMapping = false;
        } else if (this.mode === 'new') {
            // If we've already saved a new config but want to cancel,
            // we should dispatch the cancel event to leave the component entirely
            this.dispatchEvent(new CustomEvent('cancel'));
        } else {
            // For edit mode, we can just go back to basic config
            this.showBasicConfig = true;
            this.showFieldMapping = false;
        }
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