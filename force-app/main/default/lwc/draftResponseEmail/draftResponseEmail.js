import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmailDraftData from '@salesforce/apex/CaseEmailDraftController.getEmailDraftData';

export default class DraftResponseEmail extends NavigationMixin(LightningElement) {
    @api recordId;

    @api async invoke() {
        try {
            const draftData = await getEmailDraftData({ caseId: this.recordId });

            const pageRef = {
                type: 'standard__quickAction',
                attributes: {
                    apiName: 'Case.SendEmail'
                },
                state: {
                    recordId: this.recordId,
                    defaultFieldValues: encodeDefaultFieldValues({
                        Subject: draftData?.subject || '',
                        HtmlBody: draftData?.htmlBody || ''
                    })
                }
            };

            this[NavigationMixin.Navigate](pageRef);
        } catch (error) {
            console.error('Error fetching email draft data:', error);
            const message = error?.body?.message || error?.message || 'Failed to generate email draft.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Draft Email Error',
                    message: message,
                    variant: 'error'
                })
            );
        }
    }
}
