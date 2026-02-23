# Codebook Definitions Reference

Full definitions from dissertation data collection codebook for boundary resource coding.

## Table of Contents
1. [Platform Controls](#platform-controls)
2. [Application Resources](#application-resources)
3. [Development Resources](#development-resources)
4. [AI Resources](#ai-resources)
5. [Social Resources](#social-resources)
6. [Spanning Resources](#spanning-resources)
7. [Governance Resources](#governance-resources)
8. [Language Coding Guidelines](#language-coding-guidelines)

---

## Platform Controls

### AGE (API Versions)
**Definition**: Number of versions of the API.

**How to measure**: Count the number of API versions visible in documentation.

**Location**: In API documentation - visible at top of main page, in footer where API is named with version (v) and number (e.g., APIv1.1), or in code samples within URI format.

**Notes**:
- Track how often firm does releases
- Note if versioning is stable (consistent changes over time)
- Example: Main version APIv1 → branch APIv1.1 → errata APIv1.1a → addition APIv1.2 → major changes APIv2.0

### API_YEAR
**Definition**: Date value representing when the first version of the API was published.

**How to measure**: Find the year in YYYY format.

**Location**:
- Page where AGE value is found
- Blog posts announcing API launch
- Footer or copyright
- News releases on company website

---

## Application Resources

### API
**Definition**: General common set of code allowing complementor to transact with platform. May include REST-based, GraphQL, or External Worker APIs.

**Keywords**: API, Developer, Create an app, Integration, App Integrations, API connectivity, API gateway, Develop applications

**How to measure**: Count distinct APIs. Whole number from 0+.

**Counting rules**:
- Count discrete APIs, not endpoints within an API
- Do NOT count webhooks/event notifications as APIs
- Only count REST, GraphQL, or External Worker APIs that allow developers to REQUEST data or actions
- Do NOT count deprecated APIs
- Each endpoint is not another API
- Each API version does not count as another number (use AGE for versions)

### END (Endpoints)
**Definition**: Total count of distinct top-level API endpoint resources across all platform APIs.

**Location**: Documentation pages labeled "Reference," "API," "REST API," "Endpoints," or "GraphQL Schema"

**Counting rules**:
1. **REST APIs**: Count each top-level resource endpoint
   - Example: /customers, /charges, /refunds = 3 endpoints
   - Do NOT count: Sub-paths (/{id}, /{id}/sources), query parameters, or API versions
2. **GraphQL APIs**: Count each query and mutation listed in schema
3. **External Worker APIs**: Count distinct worker/job endpoints
4. **EXCLUDE**: Webhooks, event notifications, deprecated endpoints, test/sandbox-only endpoints

### METH (Methods)
**Definition**: Count of distinct HTTP methods supported across all platform APIs.

**Common methods**:
- GET – retrieve data
- POST – create new resources
- PUT – update/replace resources
- DELETE – remove resources
- PATCH – partial update

---

## Development Resources

### SDK
**Definition**: Software Development Kits - packaged set of developer tools, including programming libraries, documentation, and assets.

**Location**: Developer portal, Documentation section, GitHub

**Keywords**: SDK, Library, Libraries, Client library, Package

**How to measure**: Binary (0/1) for presence. Then count languages.

**Additional variables**:
- SDK_lang: Count of natural languages for SDK documentation
- SDK_lang_list: List of natural languages (semicolon-separated)
- SDK_prog_lang: Count of programming languages
- SDK_prog_lang_list: List (e.g., Python; JavaScript; Java; Ruby; Go; PHP; .NET)

### BUG (Debug Tools)
**Definition**: Debug/test tools in developer portals. Includes sandbox environments, error logs, test suites.

**Location**: API Developer portal, Documentation, separate testing suite, certification suite, SDK, GitHub, Docker

**Keywords**: Debug, Test, Test plans, Testing, Error, Error log, Sandbox, Try code, Docker

**How to measure**: Binary (0/1). Note types of tools available.

**Examples of tools**: Postman, Apiary, Docker, Kubernetes, sandbox environments

### STAN (Standards)
**Definition**: Use of third-party technical standards in the API.

**Standards organizations**: IETF, W3C, ISO, IEEE

**What to look for**: Foundational standards for application development, NOT just basic API transaction standards (HTTP, JSON, encryption)

**Keywords**: internet protocol, internet standard, industry standard, IETF, ISO, RFC, IEEE, W3C

**How to measure**: Binary (0/1). Record which standards found in STAN_list.

---

## AI Resources

### AI_MODEL
**Definition**: Access to AI models via API for inference, fine-tuning, or embedding generation.

**Keywords**: AI API, model access, fine-tuning, inference API, embeddings, model deployment

**Examples**: OpenAI API, Hugging Face Inference API, model serving endpoints

### AI_AGENT
**Definition**: Platform support for AI agent integration or plugin frameworks.

**Keywords**: AI agent, plugin, extension framework, agent integration

**Examples**: ChatGPT Plugins, Claude tools, agent frameworks

### AI_MKT
**Definition**: Marketplace for AI models, plugins, or agents.

**What to count**: Model hubs, plugin stores, agent stores, AI extension marketplaces

**Examples**: Hugging Face Model Hub, ChatGPT Plugin Store

**Do NOT count**: General app marketplaces (code in STORE), internal AI tools

---

## Social Resources

### COM (Communication)
**Definition**: Multiple communication channels enabling third-party developers to interact.

**Types to count**:
- COM_forum: Developer forum
- COM_blog: Developer blog
- COM_help_support: Help desk, knowledge base
- COM_live_chat: Live chat support
- COM_Slack: Developer Slack channel
- COM_Discord: Developer Discord server
- COM_stackoverflow: StackOverflow presence
- COM_training: Training resources
- COM_FAQ: FAQ section
- COM_tutorials: Tutorial content

**How to measure**: COM = total count of types present

**Note**: Do NOT count GitHub here (use GIT variable). Only count GitHub discussion boards, codespaces, collaboration features within GIT.

### GIT (GitHub/Repository)
**Definition**: Code sharing platform for distributing libraries, SDKs, documentation, and enabling developer discussion.

**Keywords**: Git, GitHub, GitLab

**How to measure**: Binary (0/1) for presence.

**Additional variables**:
- GIT_url: URL to repository
- GIT_lang: Count of natural languages
- GIT_lang_list: List of natural languages
- GIT_prog_lang: Count of programming languages in repos
- GIT_prog_lang_list: List of programming languages

### EVENT
**Definition**: Developer events hosted or sponsored by platform.

**Types**:
- EVENT_webinars: Online webinars
- EVENT_virtual: Virtual events
- EVENT_in_person: Physical events
- EVENT_conference: Developer conferences
- EVENT_hackathon: Coding competitions
- EVENT_countries: Countries where events held

---

## Spanning Resources

### SPAN
**Definition**: Resources that span boundaries between platform and external ecosystem.

**Types**:
- SPAN_internal: Internal spanning (within organization)
- SPAN_communities: Community spanning (developer communities)
- SPAN_external: External spanning (third-party integrations)

**Additional variables**:
- SPAN_lang: Count of natural languages
- SPAN_lang_list: List of natural languages
- SPAN_countries: Countries where spanning resources targeted

---

## Governance Resources

### ROLE
**Definition**: Specifies who has access and decision rights about application or function access.

**Keywords**: roles, administrator role, access, people with access, authentication, user account, OAuth, API key

**How to measure**: Binary (0/1). 1 = distinction in user or developer roles exists.

**Example**: Facebook describes user roles that need permissions when app authenticates.

### DATA
**Definition**: Data governance rules addressing provenance, usage conditions, and privacy/legal compliance.

**Keywords**: data privacy, privacy, first party data, third party data, GDPR, CCPA, data owner, data controller, data processor

**How to measure**: Binary (0/1). 1 = specific data usage policies exist in developer documentation.

### STORE (App Store/Marketplace)
**Definition**: Directory where complementors publish offerings for consumers.

**Keywords**: App store, Marketplace, App Marketplace, Integrations, App review, App approval

**How to measure**: Binary (0/1). 1 = apps can be listed in marketplace.

### CERT (Certification)
**Definition**: Registration/certification process for developers to access platform and have apps approved.

**Keywords**: Register your app, Apply for Access, Release your app, Certify, Certification

**How to measure**: Binary (0/1). 1 = any approval or certification process exists.

### OPEN (Access Model)
**Definition**: Determines if platform access is open or has payment/contract requirements.

**Values**:
- 0 = Open (no payment or contract needed)
- 1 = Partially open (free tier + paid tiers)
- 2 = Closed (payment or contract required)

**Note**: Simple terms of service agreement does NOT count as restricted access.

---

## Language Coding Guidelines

### Purpose
Language data is used to compute:
1. **Linguistic Variety**: Count of unique natural languages across all resources
2. **Ecosystem Development**: Ratio of countries with resources / countries doing business

### Recording Instructions

**When reviewing documentation, note**:
1. Is language translation presented by COUNTRY (flag icons) or by LANGUAGE name?
2. Does navigation go to country-specific sites (.com vs .de, .fr)?
3. Is Portuguese on .com or .com.br (Brazil-specific)?
4. Is French on .com, .fr, or .ca (Canada-specific)?

**For news/event coverage**:
- If global event in USA, code as USA regardless of where article published
- If local event, code to event location country

### Linguistic Variety Calculation
Count unique natural languages across ALL _lang_list columns:
- SDK_lang_list
- COM_lang_list
- GIT_lang_list
- SPAN_lang_list
- ROLE_lang_list
- DATA_lang_list
- STORE_lang_list
- CERT_lang_list
- OPEN_lang_list

Deduplicate to get LINGUISTIC_VARIETY count.

### Ecosystem Development
Calculated in analysis phase using z-scored aggregate boundary resource composite measures.
Formula: E = countries with resources / countries doing business
