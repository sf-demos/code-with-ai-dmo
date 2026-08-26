import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAIEmailDraftData from '@salesforce/apex/CaseAIEmailDraftController.getAIEmailDraftData';

export default class DraftAIResponseEmail extends NavigationMixin(LightningElement) {
    @api recordId;

    @api async invoke() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Agentforce AI',
                message: 'Analyzing patient records and generating email draft...',
                variant: 'info'
            })
        );

        try {
            const draftData = await getAIEmailDraftData({ caseId: this.recordId });

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
            console.error('Error generating AI email draft:', error);
            const message = error?.body?.message || error?.message || 'Failed to generate AI email draft.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Agentforce AI Draft Error',
                    message: message,
                    variant: 'error'
                })
            );
        }
    }
}
