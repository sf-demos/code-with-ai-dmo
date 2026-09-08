/**
 * @description Generic service for invoking Einstein prompt templates.
 *              Accepts plain Apex types (String, Id) and handles all
 *              ConnectApi wrapping internally. Tests can subclass and
 *              override callApi() to stub the ConnectApi boundary.
 */
public virtual with sharing class PromptTemplateService {

    private static final String DEFAULT_APP_NAME = 'PromptTemplateGenerationsInvocable';

    /**
     * @description Invokes an Einstein prompt template and returns the raw LLM response text.
     * @param templateApiName Developer name of the prompt template.
     * @param inputParams     Map of template input keys to values.
     *                        String values are passed as-is; Id values are
     *                        wrapped as record references ({ "id": "<id>" }).
     * @return The first generation's text from the LLM response.
     */
    public virtual String generate(String templateApiName, Map<String, Object> inputParams) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        promptInput.additionalConfig.applicationName = DEFAULT_APP_NAME;
        promptInput.isPreview = false;
        promptInput.inputParams = wrapInputParams(inputParams);

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = callApi(templateApiName, promptInput);
        return response.generations[0].text;
    }

    /**
     * @description Thin wrapper around ConnectApi.EinsteinLLM. This is the only
     *              method tests need to override to stub the external dependency.
     */
    @TestVisible
    protected virtual ConnectApi.EinsteinPromptTemplateGenerationsRepresentation callApi(
        String templateApiName,
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput
    ) {
        if (Test.isRunningTest()) {
            throw new IllegalArgumentException('PromptTemplateService.callApi should not be called from a test.');
        }
        return ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateApiName, promptInput);
    }

    /**
     * @description Invokes a prompt template and parses the LLM response as JSON.
     *              Handles markdown-wrapped responses (```json ... ```).
     * @param templateApiName Developer name of the prompt template.
     * @param inputParams     Map of template input keys to values.
     * @return Deserialized JSON as a Map.
     */
    public virtual Map<String, Object> generateJson(String templateApiName, Map<String, Object> inputParams) {
        String rawResponse = generate(templateApiName, inputParams);
        if (String.isBlank(rawResponse)) {
            return new Map<String, Object>();
        }
        String cleaned = rawResponse.trim()
            .replaceAll('(?si)^```(json)?(.*)```$', '$2')
            .trim();
        return (Map<String, Object>) JSON.deserializeUntyped(cleaned);
    }

    @TestVisible
    protected Map<String, ConnectApi.WrappedValue> wrapInputParams(Map<String, Object> inputParams) {
        Map<String, ConnectApi.WrappedValue> wrapped = new Map<String, ConnectApi.WrappedValue>();
        for (String key : inputParams.keySet()) {
            ConnectApi.WrappedValue wv = new ConnectApi.WrappedValue();
            Object value = inputParams.get(key);
            if (value instanceof Id) {
                wv.value = new Map<String, String>{ 'id' => String.valueOf(value) };
            } else {
                wv.value = value;
            }
            wrapped.put(key, wv);
        }
        return wrapped;
    }
}
