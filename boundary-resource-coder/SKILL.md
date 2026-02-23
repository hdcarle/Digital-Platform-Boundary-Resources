---
name: boundary-resource-coder
description: |
  Codes platform boundary resources from developer portals for dissertation research on platform internationalization.
  Use when: coding boundary resource variables (API, SDK, DOCS, COM, GIT, etc.) from platform developer portals;
  counting API versions, endpoints, or programming languages; recording language availability for resources;
  analyzing developer documentation for platform ecosystem research.
  Triggers: "code this platform", "analyze developer portal", "boundary resource coding", "platform API analysis"
---

# Boundary Resource Coder

Code platform boundary resources from developer portals following the dissertation data collection codebook.

## Workflow

```
1. Access developer portal URL
2. Verify platform presence (PLAT)
3. Code platform controls (AGE, API_YEAR)
4. Code Application resources (API, END, METH)
5. Code Development resources (DEVP, DOCS, SDK, BUG, STAN)
6. Code AI resources (AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA, AI_MKT)
7. Code Social resources (COM, GIT, MON, EVENT)
8. Code Spanning resources (SPAN)
9. Code Governance resources (ROLE, DATA, STORE, CERT, OPEN)
10. Record language availability for each resource type
11. Record metadata (pages_analyzed, analysis_date, coding_notes)
```

## Variable Definitions

### Platform Controls

| Variable | Definition | How to Measure |
|----------|------------|----------------|
| **AGE** | Number of API versions | Count versions (v1, v2, v3 = 3). Location: API header, footer, URI patterns |
| **API_YEAR** | Year first API published | YYYY format. Location: blog posts, footer, news releases |

### Application Resources

| Variable | Type | Definition |
|----------|------|------------|
| **API** | Count | Number of distinct APIs. Do NOT count webhooks. Only REST, GraphQL, External Worker APIs |
| **API_pages** | Count | Number of API documentation pages |
| **APIspecs** | Count | API specification languages (OpenAPI, RAML, GraphQL, etc.) |
| **APIspec_list** | List | Semicolon-separated spec languages |
| **END** | Count | Top-level endpoint resources. Do NOT count sub-paths, parameters, versions |
| **END_Pages** | Count | Endpoint documentation pages |
| **METH** | Count | HTTP methods (GET, POST, PUT, DELETE, PATCH) |
| **METH_list** | List | Semicolon-separated methods |

### Development Resources

| Variable | Type | Definition |
|----------|------|------------|
| **DEVP** | Binary | 1 = dedicated developer portal exists |
| **DOCS** | Binary | 1 = technical documentation exists |
| **SDK** | Binary | 1 = SDKs/client libraries available |
| **SDK_lang** | Count | Natural languages for SDK docs |
| **SDK_lang_list** | List | Natural languages (semicolon-separated) |
| **SDK_prog_lang** | Count | Programming languages with SDKs |
| **SDK_prog_lang_list** | List | Programming languages |
| **BUG** | Binary | 1 = debug/test tools available (sandbox, test suite, Postman) |
| **BUG_types** | List | Types of tools found |
| **BUG_prog_lang_list** | List | Programming languages in debug tools |
| **STAN** | Binary | 1 = third-party standards used (IETF, ISO, W3C, IEEE) |
| **STAN_list** | List | Standards found |

### AI Resources

| Variable | Type | Definition |
|----------|------|------------|
| **AI_MODEL** | Binary | 1 = AI model access/APIs (fine-tuning, inference) |
| **AI_MODEL_types** | List | Types of AI models |
| **AI_AGENT** | Binary | 1 = AI agent integration (plugin frameworks) |
| **AI_AGENT_platforms** | List | Agent platforms supported |
| **AI_ASSIST** | Binary | 1 = AI coding assistants available |
| **AI_ASSIST_tools** | List | AI assistant tools |
| **AI_DATA** | Binary | 1 = AI data protocols |
| **AI_DATA_protocols** | List | Data protocols |
| **AI_MKT** | Binary | 1 = AI marketplace (model hub, plugin store) |
| **AI_MKT_type** | List | Marketplace types |

### Social Resources

| Variable | Type | Definition |
|----------|------|------------|
| **COM** | Count | Total communication channels |
| **COM_lang** | Count | Natural languages on COM pages |
| **COM_lang_list** | List | Natural languages |
| **COM_forum** | Binary | 1 = forum exists |
| **COM_blog** | Binary | 1 = developer blog exists |
| **COM_help_support** | Binary | 1 = help/support exists |
| **COM_live_chat** | Binary | 1 = live chat exists |
| **COM_Slack** | Binary | 1 = Slack channel |
| **COM_Discord** | Binary | 1 = Discord server |
| **COM_stackoverflow** | Binary | 1 = StackOverflow tag |
| **COM_training** | Binary | 1 = training resources |
| **COM_FAQ** | Binary | 1 = FAQ exists |
| **COM_tutorials** | Binary | 1 = tutorials exist |
| **GIT** | Binary | 1 = Github/repo exists |
| **GIT_url** | Text | Repository URL |
| **GIT_lang** | Count | Natural languages on Github |
| **GIT_lang_list** | List | Natural languages |
| **GIT_prog_lang** | Count | Programming languages in repos |
| **GIT_prog_lang_list** | List | Programming languages |
| **MON** | Binary | 1 = monetization programs exist |
| **EVENT** | Binary | 1 = developer events exist |
| **EVENT_webinars** | Binary | 1 = webinars |
| **EVENT_virtual** | Binary | 1 = virtual events |
| **EVENT_in_person** | Binary | 1 = in-person events |
| **EVENT_conference** | Binary | 1 = conferences |
| **EVENT_hackathon** | Binary | 1 = hackathons |
| **EVENT_countries** | List | Countries where events held |

### Spanning Resources

| Variable | Type | Definition |
|----------|------|------------|
| **SPAN** | Binary | 1 = spanning resources exist |
| **SPAN_internal** | Binary | 1 = internal spanning |
| **SPAN_communities** | Binary | 1 = community spanning |
| **SPAN_external** | Binary | 1 = external spanning |
| **SPAN_lang** | Count | Natural languages |
| **SPAN_lang_list** | List | Natural languages |
| **SPAN_countries** | List | Countries for spanning resources |

### Governance Resources

| Variable | Type | Definition |
|----------|------|------------|
| **ROLE** | Binary | 1 = role-based access exists (admin, developer roles) |
| **ROLE_lang** | Count | Natural languages |
| **ROLE_lang_list** | List | Natural languages |
| **DATA** | Binary | 1 = data governance policies exist (GDPR, privacy) |
| **DATA_lang** | Count | Natural languages |
| **DATA_lang_list** | List | Natural languages |
| **STORE** | Binary | 1 = app store/marketplace exists |
| **STORE_lang** | Count | Natural languages |
| **STORE_lang_list** | List | Natural languages |
| **CERT** | Binary | 1 = certification program exists |
| **CERT_lang** | Count | Natural languages |
| **CERT_lang_list** | List | Natural languages |
| **OPEN** | Numeric | 0=open, 1=partially open, 2=closed access |
| **OPEN_lang** | Count | Natural languages |
| **OPEN_lang_list** | List | Natural languages |

## Language Recording Rules

### Format
Use semicolon-separated lists: `English; Japanese; German; French`

### What to Look For
- Language switcher (dropdown, flags)
- Country-specific domains (.de, .fr, .jp, .com.br)
- Translated documentation sections

### Important Notes
- Record if translation uses COUNTRY indicators (flags) vs LANGUAGE names
- Note country-specific URLs separately
- Each resource type tracked independently (SDK may have different languages than COM)

### Common Languages
English, Spanish, French, German, Italian, Portuguese, Japanese, Chinese (Simplified/Traditional), Korean, Russian, Arabic, Turkish, Thai, Vietnamese, Indonesian, Dutch, Polish, Swedish, Norwegian, Danish, Finnish, Czech, Hungarian, Romanian, Greek, Hebrew, Hindi

## Output Format

Produce CSV with one row per platform containing all variables from references/variable_list.csv

Required metadata columns:
- **platform_ID**: From input file
- **platform_name**: Company/platform name
- **developer_portal_url**: Working URL (update if original broken)
- **pages_analyzed**: Count of pages reviewed
- **Coder**: "Claude" or "ChatGPT"
- **analysis_date**: YYYY-MM-DD format
- **coding_notes**: Observations

## Coding Decision Rules

### When PLAT = 0 (No Platform)
If no developer portal or API exists:
- Set PLAT = 0
- Set all other variables to 0 or empty
- Note in PLAT_Notes why no platform found

### Counting APIs
- Each distinct API counts as 1 (not endpoints within an API)
- Multiple versions of same API = 1 API
- Webhooks do NOT count as APIs
- Different products (GraphQL vs REST) may be separate APIs

### Binary Variables
- 1 = feature/resource exists
- 0 = feature/resource does not exist or cannot be confirmed
- Do NOT leave blank for platforms with PLAT = 1

### List Variables
- Use semicolon separator
- Alphabetize when practical
- Standardize names (e.g., "JavaScript" not "JS", "Python" not "python")

## Resources

- **references/variable_list.csv**: Complete variable list with descriptions
- **references/codebook_definitions.md**: Full codebook definitions from dissertation
