# AI Boundary Resource Coding Prompt v2.0
## Final Version - February 15, 2026

This document contains the complete coding instructions provided to both Claude and ChatGPT AI coders for the dissertation data collection on platform boundary resources.

---

## Coding Principles

1. Code ONLY what is explicitly documented - do not infer or assume
2. Use semicolon-separated lists for all _list variables (e.g., "English; Japanese; German")
3. Binary variables are 0 or 1 only
4. Count variables are whole numbers (0, 1, 2, etc.)
5. Record ALL natural languages found for each resource type separately

---

## PLATFORM CONTROLS

### AGE (API/SDK Versions)
- **AGE** (Count): Number of versions for the platform's primary developer resource.
  - If ONLY API has versioning → count API versions (v1, v2, v3 = 3)
  - If ONLY SDK has versioning → count SDK versions
  - If BOTH have versioning → use the OLDEST one (earliest publication date)
  - Look in: API header, footer, URI patterns, SDK changelog, release notes

- **API_YEAR** (Year): Year the resource used for AGE was first published (YYYY format). Look in blog posts, changelog, footer, news releases.

---

## APPLICATION RESOURCES

### API (Binary 0/1): Platform provides API access
- **API** (Binary 0/1): APIs are available for third-party developers.
  - Code 1 if ANY documented API exists for external developers
  - Code 0 if no API is documented or available
  - Look for: API documentation, API reference, REST endpoints, GraphQL schemas
  - Authentication-only endpoints count as API=1
  - **IMPORTANT**: If GIT=1 and GitHub repositories contain API client libraries, REST API wrappers, or repos with "api" in the name (e.g., "open-banking-api", "rest-api-client", "api-sdk"), then API=1

- **APIspecs** (Count): Number of API specification languages (OpenAPI, RAML, GraphQL, etc.).
- **APIspec_list** (List): Specification languages found, semicolon-separated.

### METH (Ordinal 0-2): API Method Capability Level
- **METH** (Ordinal 0-2): API method capability level.
  - **0** = No API documented OR no methods specified
  - **1** = Read-only (GET or HEAD methods only)
  - **2** = Full CRUD capability (includes any of: POST, PUT, PATCH, DELETE)
  - Code the HIGHEST capability observed. If any write method exists, code 2.
- **METH_list** (List): Methods found, semicolon-separated.

---

## DEVELOPMENT RESOURCES

- **DEVP** (Binary 0/1): Developer portal **website** exists.
  - Code DEVP=1 if there is an actual developer portal WEBSITE with:
    - Multiple pages or sections (navigation menu, sidebar, etc.)
    - Interactive documentation (not just static text)
    - Developer-focused content organization
  - Code DEVP=0 if:
    - The "portal" is just a PDF document or link to PDF
    - Only a single static page with SDK download links
    - No actual website structure (just a document)
  - Note: A portal behind a login (REGISTRATION/RESTRICTED) still counts as DEVP=1 if it's a real website

- **DOCS** (Binary 0/1): Technical documentation exists.

- **SDK** (Binary 0/1): SDKs or client libraries are available.
  - SDK refers to general-purpose client libraries for developers (Python, JavaScript, Java, etc.)
  - AI-specific connectors (ChatGPT plugins, Claude MCP, Copilot) are coded in AI_AGENT, not SDK
  - Code 1 if ANY of: official SDK downloads, client libraries, code samples, starter templates
  - **IMPORTANT**: If GIT=1 and the GitHub repo contains code samples or libraries, then SDK=1
  - Look in: SDK section, Downloads, GitHub repos, "Get Started" sections
  - Count beta, preview, or experimental SDKs if publicly documented and downloadable
  - Do NOT count SDKs marked as "deprecated" or "unsupported"
  - Only count official SDKs published by the platform owner OR officially endorsed in documentation

- **SDK_lang** (Count): Natural languages SDK docs are available in.
- **SDK_lang_list** (List): Natural languages, semicolon-separated.
- **SDK_prog_lang** (Count): Programming languages with SDKs.
- **SDK_prog_lang_list** (List): Programming languages, semicolon-separated.

- **BUG** (Binary 0/1): Debugging/testing tools (sandbox, Postman, error logs).
- **BUG_types** (List): Types of debug tools found.
- **BUG_prog_lang_list** (List): Programming languages in debug tools.

- **STAN** (Binary 0/1): Third-party standards used (IETF, W3C, ISO, IEEE). Not basic REST/JSON.
- **STAN_list** (List): Standards found.

---

## AI RESOURCES

- **AI_MODEL** (Binary 0/1): API access to AI/ML models (LLM, embeddings, vision).
- **AI_MODEL_types** (List): Types of AI models.

- **AI_AGENT** (Binary 0/1): External AI agents can connect (ChatGPT plugin, Claude MCP, Copilot).
- **AI_AGENT_platforms** (List): AI agent platforms supported.

- **AI_ASSIST** (Binary 0/1): AI coding assistance tools for developers.
- **AI_ASSIST_tools** (List): AI assistant tools.

- **AI_DATA** (Binary 0/1): Structured data exposed for AI (MCP servers, semantic APIs).
- **AI_DATA_protocols** (List): Data protocols.

- **AI_MKT** (Binary 0/1): AI model/plugin marketplace.
- **AI_MKT_type** (List): Marketplace types.

---

## SOCIAL RESOURCES

### Communication Channels

- **COM** (Count): CALCULATED as sum of binary communication indicators below. Do NOT manually estimate.
  - COM = COM_social_media + COM_forum + COM_blog + COM_help_support + COM_live_chat + COM_Slack + COM_Discord + COM_stackoverflow + COM_training + COM_FAQ
  - NOTE: COM_tutorials and COM_Other were dropped after sample test (unreliable) and are excluded from the COM sum
  - Do NOT count GitHub here (GitHub is in GIT variable)
  - Do NOT count social media here (social media is in COM_social_media)

- **COM_lang** (Count): Natural languages on COM pages.
- **COM_lang_list** (List): Natural languages, semicolon-separated.

- **COM_social_media** (Binary 0/1): Developer-focused social media presence exists.
  - Look for: Twitter/X, LinkedIn, YouTube, Discord, or other social media accounts specifically for developers
  - Must be developer-focused accounts, not general company accounts
  - Code 1 if ANY developer social media exists, 0 if none

- **COM_forum** (Binary 0/1): Developer forum exists.
  - Look for: "forum", "community forum", "discussion board", "developer community" with threaded discussions
  - NOT just a contact form or support ticket system

- **COM_blog** (Binary 0/1): Developer blog exists.
  - Look for: "blog", "dev blog", "engineering blog", "news", "announcements" with dated articles

- **COM_help_support** (Binary 0/1): Help/support section exists.
  - Look for: "help", "support", "help center", "support center", "contact us", "get help"

- **COM_live_chat** (Binary 0/1): Live chat support exists.

- **COM_Slack** (Binary 0/1): Slack workspace/channel for developers.

- **COM_Discord** (Binary 0/1): Discord server for developers.

- **COM_stackoverflow** (Binary 0/1): StackOverflow presence.

- **COM_training** (Binary 0/1): Training/learning resources exist.

- **COM_FAQ** (Binary 0/1): FAQ section exists.

- **COM_tutorials** — **DROPPED** after sample test (unreliable). Variable was coded but is not used in analysis.
- **COM_Other** — **DROPPED** after sample test (unreliable). Variable was coded but is not used in analysis.
- **COM_Other_notes** (Text): Notes on other channels found (retained for reference).

### GitHub/Repository

- **GIT** (Binary 0/1): GitHub/GitLab repository presence.
  - Code GIT=1 if ANY GitHub or GitLab URL is mentioned anywhere in content
  - Code GIT=1 even if the URL is just mentioned but content was not scraped from it
- **GIT_url** (URL): Repository URL found.
- **GIT_lang** (Count): Natural languages on GitHub.
- **GIT_lang_list** (List): Natural languages.
- **GIT_prog_lang** (Count): Programming languages in repos.
- **GIT_prog_lang_list** (List): Programming languages.

### Monetization

- **MON** (Binary 0/1): Monetization/revenue sharing for developers.
  - Look for: monetization, incentives, earn, partner programs with revenue share

### Events

- **EVENT** (Count): CALCULATED as sum of binary event indicators below.
  - EVENT = EVENT_webinars + EVENT_virtual + EVENT_in_person + EVENT_conference + EVENT_hackathon

- **EVENT_webinars** (Binary 0/1): Platform offers regular webinars.
- **EVENT_virtual** (Binary 0/1): Platform offers virtual events for community connection.
- **EVENT_in_person** (Binary 0/1): Platform offers in-person events.
- **EVENT_conference** (Binary 0/1): Platform offers annual developer conference.
- **EVENT_hackathon** (Binary 0/1): Platform offers hackathon events.
- **EVENT_other** (Binary 0/1): Other events not in categories above.
- **EVENT_countries** (List): Countries where in-person events take place.

### Boundary Spanners

- **SPAN** (Count): CALCULATED as sum of binary spanner indicators below.
  - SPAN = SPAN_internal + SPAN_communities + SPAN_external

- **SPAN_internal** (Binary 0/1): Platform deploys internal experts/staff to work with developers.
- **SPAN_communities** (Binary 0/1): Platform has organized community groups.
- **SPAN_external** (Binary 0/1): Platform recruits external subject matter experts.
- **SPAN_lang** (Count): Natural languages for spanning resources.
- **SPAN_lang_list** (List): Natural languages.
- **SPAN_countries** (List): Countries for spanning resources.

---

## GOVERNANCE RESOURCES

- **ROLE** (Binary 0/1): Role-based access/permissions documented.
- **ROLE_lang** (Count): Natural languages for role documentation.
- **ROLE_lang_list** (List): Natural languages.

- **DATA** (Binary 0/1): Data governance policies for developers (GDPR, privacy).
- **DATA_lang** (Count): Natural languages for data policies.
- **DATA_lang_list** (List): Natural languages.

- **STORE** (Binary 0/1): App store/marketplace exists.
- **STORE_lang** (Count): Natural languages in app store.
- **STORE_lang_list** (List): Natural languages.

- **CERT** (Binary 0/1): Official app/integration certification or approval process exists.
  - Code CERT=1 if there is a formal review/approval process for apps or integrations
  - **NOT about security certifications** (SOC2, ISO, GDPR compliance are NOT CERT)
  - Look for: "submit for review", "approval process", "certification requirements"
- **CERT_lang** (Count): Natural languages for certification documentation.
- **CERT_lang_list** (List): Natural languages.

- **OPEN** — **DROPPED** from analysis after sample test. Variable was coded but is not used in the model.
  - Original definition: Platform openness level (0 = Open, 1 = Partial, 2 = Closed)
  - OPEN_lang and OPEN_lang_list also dropped.

---

## CALCULATED FIELDS (Post-processing only)

**LEAVE THESE BLANK** - They are calculated automatically after coding is complete:
- **LINGUISTIC_VARIETY**: Calculated from all _lang_list fields
- **linguistic_variety_list**: Calculated from all _lang_list fields
- **programming_lang_variety**: Calculated from all _prog_lang_list fields
- **programming_lang_variety_list**: Calculated from all _prog_lang_list fields

---

## LANGUAGE RECORDING RULES

For each resource type with _lang columns, use this PRIORITY ORDER:

1. **FIRST: Check for language switcher/selector** (PREFERRED SOURCE)
   - Look for dropdown menus, globe icons, flag icons on main portal page
   - If found, record ALL languages shown in the switcher

2. **SECOND: Check for country-specific domains** (if no switcher)
   - Look for .de, .fr, .jp, .com.br, /es/, /zh/ in URLs

3. **THIRD: Count confirmed translated content** (fallback)
   - Only count languages with actual translated content found

4. **Record languages consistently**:
   - Use semicolon separator: "English; Japanese; German"
   - Record for EACH resource type separately

---

## VALID PROGRAMMING LANGUAGES

ONLY count and list these programming languages:

Ada, Apex, Assembly, Bash/Shell, C, C#, C++, Clojure, Cobol, Crystal, Dart, Delphi, Elixir, Erlang, F#, Fortran, GDScript, Go, Groovy, Haskell, HTML/CSS, Java, JavaScript, Julia, Kotlin, Lisp, Lua, MATLAB, MicroPython, Nim, Objective-C, OCaml, Perl, PHP, PowerShell, Prolog, Python, R, Ruby, Rust, Scala, Solidity, SQL, Swift, TypeScript, VBA, Visual Basic, Zephyr

**NOT Programming Languages (DO NOT list):**
- Game engines/platforms: Unity, Unreal, Native
- Mobile platforms: iOS, Android, Flutter, React Native, Xamarin
- Frameworks/runtimes: .NET, Node.js, Spring, Django, Rails

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 5, 2026 | Initial coding prompt |
| 2.0 | Feb 15, 2026 | Dropped END, END_pages, API_pages; METH changed to ordinal (0-2); COM_social_media changed to binary; SDK linked to GIT samples |
| 2.1 | Feb 15, 2026 | API changed from count to binary (0/1) to reduce IRR disagreements and align with theoretical framework |
| 2.2 | Feb 19, 2026 | Added GitHub→API inference rule: if GIT=1 and repos contain API client libraries or "api" in repo names, code API=1 (mirrors existing SDK→GIT rule) |
| 2.3 | Feb 23, 2026 | Aligned with codebook v2.0 updates: marked OPEN as DROPPED, marked COM_tutorials and COM_Other as DROPPED (unreliable after sample test), updated COM sum formula to exclude dropped variables, added COM_social_media to COM sum |

