# AGENTS.md

## Repository Overview
- **Project**: Salesforce DX source-format project (`force-app/main/default`).
- **Domain**: Client-neutral demo for **HealthPulse** (Continuous Health Monitoring / medical sensor POC).
- **Core Components**: Service Cloud Case email drafting using Einstein Prompt Templates, Aloha Email Templates, and LWC headless actions.

## Key Rules & Gotchas for AI Agents

1. **Testing & Verification**:
   - This repository is a Salesforce metadata/Apex POC and does **not** contain JavaScript/LWC Jest test suites.
   - You do **not** need to perform or run unit tests before committing and pushing.
   - Do **not** run `npm test` or `npm install` expecting unit tests to pass.

2. **Formatting & XML Integrity**:
   - Keep Salesforce XML tags (`.app-meta.xml`, `.flexipage-meta.xml`, etc.) clean and single-lined (especially `<comment>`, `<value>`, and `<label>`).
   - `.prettierrc` has `printWidth: 120` configured for XML files.

3. **Branding & Neutrality**:
   - Always use **HealthPulse** and **Continuous Health Monitoring (CHM)**. Never introduce client-specific names (Dexcom, G7, CGM).

## File Locations
- **Apps & Navigation**: `force-app/main/default/applications/`
- **Flexipages (Record Views)**: `force-app/main/default/flexipages/`
- **Apex Classes**: `force-app/main/default/classes/`
- **GenAI Prompt Templates**: `force-app/main/default/genAiPromptTemplates/`
- **Email Templates**: `force-app/main/default/email/`
- **Objects & Custom Fields**: `force-app/main/default/objects/`
