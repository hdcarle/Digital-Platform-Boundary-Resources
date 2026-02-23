#!/usr/bin/env python3
"""
ChatGPT/OpenAI Boundary Resource Coding Agent
==============================================
Codes 102 boundary resource variables from scraped developer portal content.
Uses same coding rules as Claude for IRR comparison.
Handles PLAT = NONE by auto-zero coding all variables.

Usage:
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --output results/
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --limit 5  # Test on 5
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --dry-run  # Preview

Input:
    - Scraped content folder (from page_scraper.py)
    - Tracker file with PLAT coding
Output:
    - JSON files per platform
    - Combined CSV for CODE_BOOK import
"""

import os
import sys
import json
import argparse
import time
from datetime import datetime
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    print("ERROR: pandas not installed. Run: pip3 install pandas openpyxl")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai not installed. Run: pip3 install openai")
    sys.exit(1)


# ============================================================================
# CONFIGURATION
# ============================================================================

MODEL = "gpt-4o"  # or "gpt-4o-mini" for cheaper, "gpt-4-turbo" for different
MAX_TOKENS = 8192

# Auto-zero template for PLAT = NONE (same as Claude)
AUTO_ZERO_RESULT = {
    "platform_controls": {
        "AGE": 0,
        "API_YEAR": ""
    },
    "application": {
        "API": 0,
        "METH": 0, "METH_list": ""
    },
    "development": {
        "DEVP": 0, "DOCS": 0,
        "SDK": 0, "SDK_lang": 0, "SDK_lang_list": "", "SDK_prog_lang": 0, "SDK_prog_lang_list": "",
        "BUG": 0, "BUG_types": "", "BUG_prog_lang_list": "",
        "STAN": 0, "STAN_list": ""
    },
    "ai": {
        "AI_MODEL": 0, "AI_MODEL_types": "",
        "AI_AGENT": 0, "AI_AGENT_platforms": "",
        "AI_ASSIST": 0, "AI_ASSIST_tools": "",
        "AI_DATA": 0, "AI_DATA_protocols": "",
        "AI_MKT": 0, "AI_MKT_type": ""
    },
    "social": {
        "COM_lang": 0, "COM_lang_list": "",
        "COM_social_media": 0, "COM_forum": 0, "COM_blog": 0, "COM_help_support": 0,
        "COM_live_chat": 0, "COM_Slack": 0, "COM_Discord": 0, "COM_stackoverflow": 0,
        "COM_training": 0, "COM_FAQ": 0,
        "GIT": 0, "GIT_url": "", "GIT_lang": 0, "GIT_lang_list": "", "GIT_prog_lang": 0, "GIT_prog_lang_list": "",
        "MON": 0,
        "EVENT": 0, "EVENT_webinars": 0, "EVENT_virtual": 0, "EVENT_in_person": 0,
        "EVENT_conference": 0, "EVENT_hackathon": 0, "EVENT_other": 0, "EVENT_countries": "",
        "SPAN": 0, "SPAN_internal": 0, "SPAN_communities": 0, "SPAN_external": 0,
        "SPAN_lang": 0, "SPAN_lang_list": "", "SPAN_countries": ""
    },
    "governance": {
        "ROLE": 0, "ROLE_lang": 0, "ROLE_lang_list": "",
        "DATA": 0, "DATA_lang": 0, "DATA_lang_list": "",
        "STORE": 0, "STORE_lang": 0, "STORE_lang_list": "",
        "CERT": 0, "CERT_lang": 0, "CERT_lang_list": "",
        "OPEN": 0, "OPEN_lang": 0, "OPEN_lang_list": ""  # 0 = Closed for NONE
    },
    "moderators": {
        "home_primary_lang": "", "language_notes": ""
    }
}


# ============================================================================
# CODING PROMPT (Same as Claude for IRR consistency)
# ============================================================================

SYSTEM_PROMPT = '''You are a specialized research assistant coding digital platform boundary resources for academic research on platform internationalization. You must follow the codebook rules exactly and return only valid JSON output.

Key principles:
1. Code ONLY what is explicitly documented - do not infer or assume
2. Use semicolon-separated lists for all _list variables (e.g., "English; Japanese; German")
3. Binary variables are 0 or 1 only
4. Count variables are whole numbers (0, 1, 2, etc.)
5. Record ALL natural languages found for each resource type separately
6. METH RULE: For METH, you MUST find HTTP method names (GET, POST, PUT, DELETE, PATCH) used in API documentation contexts — endpoint definitions, cURL examples, REST request descriptions, OAuth token flows, or API overview pages. Do NOT count "blog post", "patch notes", "delete your account", or "get started" as HTTP methods — only count them in API documentation context. If the platform uses OAuth, POST is almost certainly used for token requests. Code METH based on what documentation describes.'''

CODING_PROMPT = '''PLATFORM: {platform_name}
PLATFORM ID: {platform_id}
PLAT STATUS: {plat_status}
DEVELOPER PORTAL URL: {portal_url}

Analyze the provided developer portal content and code ALL boundary resource variables according to these rules:

## PLATFORM CONTROLS

### AGE (API/SDK Versions)
- **AGE** (Count): Number of versions for the platform's primary developer resource.
  - If ONLY API has versioning → count API versions (v1, v2, v3 = 3)
  - If ONLY SDK has versioning → count SDK versions
  - If BOTH have versioning → use the OLDEST one (earliest publication date)
  - Look in: API header, footer, URI patterns, SDK changelog, release notes
- **API_YEAR** (Year): Year the resource used for AGE was first published (YYYY format). Look in blog posts, changelog, footer, news releases.

## APPLICATION RESOURCES

### API (Binary 0/1): Platform provides API access
- **API** (Binary 0/1): APIs are available for third-party developers to transact with the platform.
  - Code 1 if:
    - Documentation exists for REST, GraphQL, or External Worker APIs that allow developers to REQUEST data or perform actions
    - Page is specifically about the platform's API for external developers (not internal integrations the company built with others)
    - Registration/login page EXISTS for API/developer access (even if docs are behind the wall)
    - Evidence includes: API reference pages, endpoint documentation, authentication guides for API access
  - Code 0 if:
    - No API documentation found
    - Only webhooks/event notifications exist (these are NOT APIs)
    - Only mentions "we integrate with X" without developer-facing API docs
    - Only deprecated APIs exist
  - Keywords: API, Developer, Create an app, Integration, App Integrations, API connectivity, API gateway, Develop applications, Register for API
  - Location: Corporate website; tab that indicates API or Developer
  - NOTE: If a developer registration page exists (e.g., "Sign up for API access", "Create a developer account"), code API=1 even if full documentation is behind the login wall.
  - **PLAT-CONDITIONAL GUIDANCE**:
    - If PLAT=PUBLIC: The platform almost certainly has an API or SDK (or both). Look harder for exact keyword matches. "API" must appear as a standalone term (not as letters within another word like "capital"). If the portal has documentation, getting-started guides, or endpoint references, code API=1.
    - If PLAT=REGISTRATION: Public-facing pages may discuss the API even if full docs are behind login. Look for "API" on landing pages, feature descriptions, or registration prompts.
    - If PLAT=RESTRICTED: Low probability of finding API documentation since access requires approval. Code 0 if no evidence found — do not infer.
  - **IMPORTANT**: If GIT=1 and GitHub repositories contain API client libraries, REST API wrappers, or repos with "api" in the name (e.g., "open-banking-api", "rest-api-client", "api-sdk"), then API=1
  - DO NOT count: individual endpoints, API versions (v1 vs v2 = same API), webhooks, or auth flows

### METH (Ordinal 0-2): API method capability level
- **METH** (Ordinal 0-2): API method capability level.
  - **0** = No API documented OR no methods specified
  - **1** = Read-only (GET/HEAD only)
  - **2** = Full CRUD capability (includes any of: POST, PUT, PATCH, DELETE)
  - Code the HIGHEST capability observed. If any write method exists, code 2.
  - Counting rules:
    1. Identify HTTP methods documented: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
    2. If none found, code as 0
    3. If only GET found, code as 1
    4. If more than GET is found (e.g., POST, PUT, DELETE), code as 2
  - Keywords: Get, Put, Post, Delete, Patch, Method, Create, Edit, HTTP
  - Location: The same page that discusses the endpoints or pages within 1-2 clicks on the navigation menu
  - NOTE: Response formats (JSON, XML, YAML) are NOT counted in METH - this variable focuses specifically on HTTP method variety.
  - **CRITICAL DISAMBIGUATION**: Only count GET, POST, PUT, DELETE, PATCH when they refer to **HTTP API methods**. Do NOT count these words when used as ordinary English:
    - "blog post", "Read blog post", "post a review" → NOT HTTP POST
    - "Patch Notes", "game patch", "software patch" → NOT HTTP PATCH
    - "delete your account", "delete personal data" → NOT HTTP DELETE (unless in API endpoint context like DELETE /users/user_id)
    - "get started", "get support" → NOT HTTP GET (unless in API endpoint context like GET /api/players/player_id)
    - "put your skills to work" → NOT HTTP PUT
  - **WHERE TO LOOK FOR METHODS**: Methods may appear in any of these contexts:
    - Endpoint definitions (e.g., "GET /api/v1/players")
    - cURL commands or request examples
    - SDK method signatures
    - API documentation describing request types
    - OAuth documentation describing token requests (POST to token endpoint)
    - API overview pages mentioning "GET requests" or "POST data"
    - Getting Started guides that describe making API calls
  - IMPORTANT: If the platform documents OAuth authentication, it almost certainly uses POST for token requests. If API docs mention retrieving data, GET is implied. Code based on what the documentation describes, not just explicit endpoint listings.
- **METH_list** (List): Methods found, semicolon-separated.

## DEVELOPMENT RESOURCES

- **DEVP** (Binary 0/1): Developer portal **website** exists.
  - **IMPORTANT**: If the platform has a developer_portal_url (i.e., PLAT is PUBLIC, REGISTRATION, or RESTRICTED), then DEVP should almost always be coded 1. The URL was verified as pointing to a real developer portal. Only code DEVP=0 if:
    - The URL points to just a single PDF document (not a website)
    - The URL is only an SDK download page with no other developer resources
    - The scraped content shows no website structure at all
  - Code DEVP=1 if there is an actual developer portal WEBSITE with:
    - Multiple pages or sections (navigation menu, sidebar, etc.)
    - Interactive documentation (not just static text)
    - Developer-focused content organization
  - A portal behind a login (REGISTRATION/RESTRICTED) still counts as DEVP=1 if it's a real website
  - Look for evidence: multiple scraped pages, navigation structure, page titles suggesting website
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
- **SDK_lang_list** (List): Natural languages, semicolon-separated (e.g., "English; Japanese; German").
- **SDK_prog_lang** (Count): Programming languages with SDKs (see VALID PROGRAMMING LANGUAGES list below).
- **SDK_prog_lang_list** (List): Programming languages, semicolon-separated. ONLY use languages from the valid list.
- **BUG** (Binary 0/1): Debugging, testing, or quality assurance tools provided to developers.
  - Code BUG=1 (YES) if the platform provides ANY of these tools or environments:
    - Sandbox or test environments
    - Mock data or test credentials
    - Interactive API consoles (try-it-out, API explorer)
    - Debugging tools (profilers, inspectors, log viewers)
    - Postman collections, Insomnia configs, or similar
    - Docker containers for local testing
    - Error simulators or test harnesses
    - CI/CD integration tools
  - Code BUG=0 (NO) if NONE of the above tools exist and ONLY these are found:
    - Only error code documentation exists (listing HTTP 400/500 errors is DOCS, not BUG)
    - Only troubleshooting FAQ pages exist without actual tools
    - Only "known issues" lists without testing tools
  - Keywords: 'sandbox', 'test environment', 'mock', 'debug', 'profiler', 'Postman',
    'Docker', 'test plan', 'API console', 'try it', 'interactive', 'playground',
    'emulator', 'simulator', 'error log', 'inspector'
  - Location: Developer tools section, testing documentation, getting started guides
- **BUG_types** (List): Types of debug/test tools found.
- **BUG_prog_lang_list** (List): Programming languages in debug tools.
- **STAN** (Binary 0/1): Third-party interoperability standards adopted by the platform.
  - The platform uses or develops public technical standards for interoperability of features.
    It is expected that platforms will use accepted standards for SOAP, REST or GraphQL APIs,
    common formats like HTML, JSON or JSON-LD, and common authentication/security standards.
    Those basic standards are NOT interesting for this analysis. Rather, we are interested in
    whether there are specific third-party protocols used for interoperability of features,
    or whether the platform attempts to create its own.
  - Common standards organizations:
    - IETF (Internet Engineering Task Force) — publishes RFCs (Requests for Comment)
      for internet protocols beyond basic HTTP/TLS
    - W3C (World Wide Web Consortium) — web/mobile standards including encryption,
      blockchain, verifiable credentials, payments, accessibility
    - ISO (International Organization for Standardization) — quality, safety, IT security,
      financial services standards
    - IEEE — engineering standards in energy, aerospace, IT, communications
    - Khronos Group — graphics and compute standards (Vulkan, OpenGL, OpenXR, OpenCL)
  - Examples that COUNT as STAN=1:
    - OAuth / OAuth 2.0 (IETF RFC 6749)
    - OpenID Connect (OIDC)
    - Vulkan, OpenGL, OpenXR, OpenCL (Khronos Group)
    - TWAIN (scanner/imaging standard)
    - WebRTC, WebSocket protocols (W3C/IETF)
    - SAML, SCIM (identity standards)
    - FIDO/WebAuthn (authentication standards)
    - ISO financial services standards, ISO 27001 security
    - Any named IETF RFC, W3C Recommendation, ISO standard, or IEEE standard
      that is foundational to the application being developed
  - Do NOT count these as STAN (basic API transaction standards):
    - REST, SOAP, GraphQL (expected API styles)
    - HTTP/HTTPS, JSON, JSON-LD, XML, HTML, CSS (basic web formats)
    - TLS/SSL (basic transport security/encryption)
    - UTF-8 or character encoding
    - Basic app authentication patterns unless they reference a specific RFC or standard by name
  - Keywords: 'internet protocol', 'internet standard', 'industry standard', 'IETF',
    'ISO', 'RFC', 'IEEE', 'W3C', 'Khronos', 'OAuth', 'OpenID', 'Vulkan', 'OpenGL',
    'OpenXR', 'TWAIN', 'WebRTC', 'SAML', 'FIDO', 'specification', 'compliance'
  - Location: Developer portal documentation, API docs, GitHub repos. Look for standards
    organization abbreviations noted with their specific name or number of a related standard.
    Or, the organization may refer to some other industry standard commonly agreed upon
    by an industry organization.
  - CRITICAL: The mention should be foundational to the application that is to be
    developed and NOT merely adherence to the basic standards to transact with the API.
- **STAN_list** (List): Standards found, semicolon-separated.

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

## SOCIAL RESOURCES

- **COM_lang** (Count): Natural languages on COM pages.
- **COM_lang_list** (List): Natural languages, semicolon-separated.
- **COM_social_media** (Binary 0/1): Any company-owned social media account is referenced or linked from the developer portal.
  - Code 1 if ANY social media account link or reference appears ANYWHERE on the developer portal, including:
    - Social media icons in the header, footer, or sidebar (very common — check footer carefully)
    - Hyperlinks to Twitter/X, LinkedIn, YouTube, Facebook, Instagram, etc. in narrative text
    - "Follow us" or "Connect with us" sections
    - Embedded social media feeds or widgets
  - Code 0 ONLY if NO social media links exist anywhere on the developer portal pages
  - Keywords: "Twitter", "X", "LinkedIn", "YouTube", "Facebook", "Instagram", "follow us", social media icons
  - NOTE: This does NOT need to be a developer-specific account. Any company social media account linked from the developer portal counts.
  - NOTE: Discord is coded separately under COM_Discord. Do NOT count Discord links as COM_social_media.
- **COM_forum** (Binary 0/1): Developer forum discrete from GitHub exists with threaded discussions.
  - Keywords: "forum", "community forum", "discussion board", "developer community", "discussions", "ask a question", "community", "developer hub", "Q&A"
  - Look in: navigation links, footer, community pages, support pages — forums are often linked from main navigation under "Community" or "Support"
  - NOT just a contact form or support ticket system
  - Note: forum and community pages may also contain links to Discord, Slack, or other chat platforms — check these pages when coding COM_Discord and COM_Slack
- **COM_blog** (Binary 0/1): Blog specifically for developer information, platform changes, or release notes exists with multiple dated posts.
  - Keywords: "blog", "dev blog", "engineering blog", "news", "announcements", "changelog", "what's new", "release notes"
  - Must have multiple posts or articles, not just a single page
- **COM_help_support** (Binary 0/1): Help or support pages are offered with customer service information.
  - Keywords: "help", "support", "help center", "support center", "contact us", "get help", "submit a ticket"
  - Includes ticket systems, email support, phone support
  - **DO NOT code 1 just because an FAQ page exists — COM_FAQ is a separate variable.** Similarly, forums (COM_forum), Discord (COM_Discord), and Slack (COM_Slack) are their own variables and do NOT count as help_support. COM_help_support requires a dedicated support channel where a user can contact a support team (e.g., support email, phone line, ticket system, contact form).
- **COM_live_chat** (Binary 0/1): Customer service pages contain a live chat feature, including AI bots.
  - Keywords: "live chat", "chat with us", "chat now"
  - Look for: chat widget, Intercom, Zendesk chat, Drift, or AI chatbot popup
  - Must be real-time chat, not just a contact form
- **COM_Slack** (Binary 0/1): Slack channel offered for developers to communicate with platform staff or each other.
  - Keywords: "Slack", "Join our Slack", "slack.com"
  - Also check forum, community, and GitHub pages where these links are often posted
- **COM_Discord** (Binary 0/1): Discord channel offered for developers to communicate with platform staff or each other.
  - Keywords: "Discord", "Join our Discord", "discord.gg"
  - Also check forum, community, and GitHub pages where these links are often posted
- **COM_stackoverflow** (Binary 0/1): StackOverflow's knowledge sharing platform is used or linked to from the dev portal.
  - Keywords: "StackOverflow", "Stack Overflow", "stackoverflow.com"
- **COM_training** (Binary 0/1): Developer portal offers dedicated learning resources for developers.
  - Includes recorded or on-demand training courses, academies, coding tutorials, and how-to walkthroughs that teach developers to build with the platform
  - Keywords: "training", "academy", "tutorial", "course", "learn", "how-to", "walkthrough"
  - Do NOT count standard API/SDK reference documentation or getting started pages
  - Do NOT count live webinars (those are coded under EVENT_webinars)
  - Do NOT count certification programs (those are coded under CERT)
- **COM_FAQ** (Binary 0/1): Dev portal has a frequently asked questions section.
  - Keywords: "FAQ", "frequently asked questions", "common questions", "Q&A"
- **GIT** (Binary 0/1): GitHub/GitLab repository presence.
  - Code GIT=1 if ANY GitHub or GitLab URL is mentioned anywhere in content (e.g., "github.com/company", "gitlab.com/org")
  - Code GIT=1 even if the URL is just mentioned but content was not scraped from it
  - Do NOT require actual repository analysis to code GIT=1
- **GIT_url** (URL): Repository URL found. Capture even if content not scraped.
- **GIT_lang** (Count): Natural languages on GitHub. GitHub/GitLab is in English by default, so if GIT=1, code GIT_lang=1 minimum (English).
- **GIT_lang_list** (List): Natural languages. If GIT=1, at minimum: "English".
- **GIT_prog_lang** (Count): Programming languages in repos (see VALID PROGRAMMING LANGUAGES list below).
  - **FIRST**: Look for a "GITHUB REPOSITORY LANGUAGES" section in the content — if present, use the "Codebook-valid programming languages" line and "GIT_prog_lang count" directly.
  - **SECOND**: If no GitHub language section exists but GIT=1 from URL mention only, leave as 0 and note "GIT_prog_lang requires manual verification" in coding_notes.
- **GIT_prog_lang_list** (List): Programming languages from the valid list only.
  - **FIRST**: If a "GITHUB REPOSITORY LANGUAGES" section exists, copy the codebook-valid languages listed there.
  - **SECOND**: If no GitHub language section, leave blank.
- **MON** (Binary 0/1): Monetization or revenue-sharing programs for developers.
  - Code 1 if the platform offers programs where developers can earn money or
    receive financial benefits:
    - Revenue sharing (ad revenue, in-app purchase splits, royalty programs)
    - Developer monetization programs (earn from content, apps, or integrations)
    - Partner programs with explicit financial tiers or incentive structures
    - Affiliate or referral programs with developer payouts
    - Marketplace where developers sell apps/plugins and receive revenue
  - Code 0 if:
    - Only a generic partner program exists without financial benefits mentioned
    - The platform sells to developers but does not pay developers
    - Free tier or credits offered (that is OPEN, not MON)
    - Partnership is about co-marketing without revenue sharing
  - Keywords: 'monetization', 'monetize', 'revenue share', 'earn', 'payout',
    'partner program', 'affiliate', 'royalty', 'developer fund', 'incentive',
    'marketplace earnings', 'commission'
  - Location: Partner pages, monetization section, developer programs, marketplace terms
  - COMMON ERRORS TO AVOID:
    - MON is about developers EARNING money FROM the platform — not about developers PAYING the platform
    - Paid API tiers, pricing pages, or billing settings where developers PAY for access are NOT MON=1 (those relate to OPEN)
    - Revenue share percentages (e.g., "70/30 split", "developers earn 70%") = MON=1
    - Marketplace where developers sell apps/content and receive payouts = MON=1
    - A developer fund, grant program, or bounty program where the platform pays developers = MON=1
    - Do NOT confuse API pricing (developer pays platform) with monetization (platform pays developer)
- **EVENT** (Count): CALCULATED as sum of binary event indicators below.
  - EVENT = EVENT_webinars + EVENT_virtual + EVENT_in_person + EVENT_conference + EVENT_hackathon
  - Do NOT manually estimate - calculate from components
- **EVENT_webinars** (Binary 0/1): Platform offers regular webinars about API functionality.
  - Live informational events, different from training sessions
- **EVENT_virtual** (Binary 0/1): Platform offers virtual events for community connection.
  - Large Zoom meetings, virtual conferences - often "virtual" in title
  - Different from one-way webinar - allows developer community interaction
- **EVENT_in_person** (Binary 0/1): Platform offers in-person events.
  - Regional events, meetups, meetings at industry conferences
- **EVENT_conference** (Binary 0/1): Platform offers annual developer conference.
  - Like Google DevFest - dedicated developer conference
  - NOT general sales conferences unless they have specific developer tracks
- **EVENT_hackathon** (Binary 0/1): Platform offers hackathon events.
  - In-person or online hackathons to build apps
- **EVENT_other** (Binary 0/1): Other events not in categories above.
- **EVENT_countries** (List): Countries where in-person events take place.
- **SPAN** (Count): CALCULATED as sum of binary spanner indicators below.
  - SPAN = SPAN_internal + SPAN_communities + SPAN_external
  - Do NOT manually estimate - calculate from components
- **SPAN_internal** (Binary 0/1): Platform deploys internal experts/staff to work with developers.
  - Dedicated technical account managers, paid or free support staff
- **SPAN_communities** (Binary 0/1): Platform has organized community groups.
  - Student Ambassadors, Women in Tech, local developer communities
  - NOT the same as a forum - these are dedicated organized groups
- **SPAN_external** (Binary 0/1): Platform recruits external subject matter experts.
  - Google Product Experts, MVP programs, community champions
  - External individuals whose knowledge is evangelized
- **SPAN_lang** (Count): Natural languages for spanning resources.
- **SPAN_lang_list** (List): Natural languages.
- **SPAN_countries** (List): Countries for spanning resources.

## GOVERNANCE RESOURCES

- **ROLE** (Binary 0/1): Specifies who has access and decision rights about access to the application or functions.
  - Code 1 if documentation shows ANY of the following:
    - DIFFERENT ACTIONS require DIFFERENT PERMISSION LEVELS (e.g., read vs. write, admin vs. user)
    - OAuth scopes that grant different levels of access (e.g., "profile.read" vs. "profile.write")
    - Registration/authentication process that assigns access levels or scopes to developers
    - Developer must register and be granted specific permissions or API scopes before accessing resources
    - Terms of use that specify what developers can and cannot do with different types of access
    - Different account tiers with different API capabilities (free vs. business vs. enterprise developer accounts)
  - Code 0 if:
    - No authentication or registration of any kind — completely open public API
    - Only a single generic API key with no scope differentiation
    - No mention of any access levels, permissions, or scopes in documentation
  - Keywords: roles, administrator, access, authentication, OAuth, scope, permissions, register, account type, authorization
  - Location: Setup pages, authentication docs, access/permissions documentation, OAuth docs, Terms of Use
  - IMPORTANT: OAuth with scoped access IS ROLE=1. If the platform uses OAuth and documentation mentions different scopes or permissions (even implicitly through the OAuth flow), code ROLE=1.
  - COMMON ERRORS TO AVOID:
    - DO NOT code ROLE=0 just because it uses simple OAuth — OAuth inherently involves scoped access rights
    - Generic user account settings (profile, notifications) alone are NOT role-based access control
    - "Sandbox vs production" access levels are NOT roles — those relate to OPEN variable
- **ROLE_lang** (Count): Natural languages for role documentation.
- **ROLE_lang_list** (List): Natural languages.
- **DATA** (Binary 0/1): Data governance policies exist that address how developers can use data from the platform.
  - Code 1 if ANY of the following exist on or linked from the developer portal:
    - Terms of Use, Terms of Service, or Developer Agreement that specifies what developers can/cannot do with data obtained through APIs
    - API Terms of Use that mention data usage, data restrictions, or data handling obligations
    - Data Protection Notice or Data Policy linked from or mentioned on the developer portal or its forums
    - Developer documentation that specifies data usage conditions, data retention limits, or data sharing restrictions
    - Privacy policy that includes SPECIFIC sections about third-party developer data usage (not just end-user privacy)
    - GDPR/CCPA compliance documentation that outlines developer obligations
    - Data classification or data handling requirements in SDK or API documentation
  - Code 0 if:
    - No terms of use, data policy, or data governance documentation exists at all
    - No mention of data usage rules anywhere on the developer portal or linked pages
    - The platform has no API/SDK (and therefore no data governance needed)
  - Keywords: 'terms of use', 'terms of service', 'developer agreement', 'data policy',
    'data protection', 'data governance', 'API terms', 'user data', 'data privacy',
    'GDPR', 'CCPA', 'data owner', 'data controller', 'data processor', 'data retention'
  - Location: Terms of use page, footer links, governance documentation, forum pinned posts, developer agreement
  - IMPORTANT: Most developer portals with APIs will have some form of Terms of Use or Developer Agreement that governs data usage. If you find ANY such document that specifies how developers should handle data obtained through the API, code DATA=1. You do NOT need a standalone "Data Policy" page — terms embedded in a Developer Agreement or API Terms of Use count.
  - COMMON ERRORS TO AVOID:
    - DO NOT require a dedicated "Data Policy" page — data terms within a Developer Agreement or Terms of Use count as DATA=1
    - DO NOT code DATA=0 just because the terms are part of a broader Terms of Use document
    - A company privacy policy that ONLY addresses end users with NO mention of developer/API data usage is NOT DATA=1
- **DATA_lang** (Count): Natural languages for data policies.
- **DATA_lang_list** (List): Natural languages.
- **STORE** (Binary 0/1): App store or marketplace where third-party developers can publish, distribute, or sell apps, plugins, extensions, integrations, or add-ons.
  - Code 1 if the platform has ANY of:
    - A dedicated app store, marketplace, or gallery page (e.g., "App Marketplace", "Extension Store", "Plugin Directory")
    - A section where third-party apps/integrations are listed for end users to install
    - Documentation describing how developers submit apps to a store or marketplace
    - References in narrative text to "our app store", "marketplace", "app directory", "extension gallery", "plugin store"
  - Code 0 if:
    - No app store or marketplace exists
    - Only a list of the company's OWN integrations (not third-party developer submissions)
    - Only an API exists without a distribution channel for third-party apps
  - Keywords: "app store", "marketplace", "app directory", "extension store", "plugin store", "app gallery", "add-on store", "integration marketplace", "publish your app", "submit your app", "list your app"
  - Location: Main navigation, developer documentation, partner pages
- **STORE_lang** (Count): Natural languages in app store.
- **STORE_lang_list** (List): Natural languages.
- **CERT** (Binary 0/1): Official app/integration certification or approval process exists.
  - Code CERT=1 if there is a formal review/approval process for apps or integrations to be listed/published
  - Examples of CERT=1: App store review process, certification program, validation badge, "certified partner" requirements
  - Code CERT=0 if developers can publish/integrate without formal approval
  - **NOT about security certifications** (SOC2, ISO, GDPR compliance are NOT CERT - those go in STAN or DATA)
  - Look for: "submit for review", "approval process", "certification requirements", "verified/certified apps"
- **CERT_lang** (Count): Natural languages for certification documentation.
- **CERT_lang_list** (List): Natural languages.
- **OPEN** (Binary 0/1): Whether the platform provides open access to developers as a boundary resource.
  - **1 = Open**: Developers can access the platform's APIs/SDKs/resources through free self-service registration or public access. This includes platforms with free tiers even if paid upgrades exist. The platform provides openness as a resource to its ecosystem.
  - **0 = Closed**: No free self-service access exists. Developers must pay, apply and wait for manual approval, sign a contract, or join a partner program before accessing ANY platform resources.
  - Keywords: Register, Get access, Create an account, pricing, contract, free tier, rate limit, quota, apply, request access
  - Location: Developer site, Partners/Partnerships page, pricing page
  - Code 1 (Open) if ANY of these are true:
    - Free self-service registration (sign up, get instant or automated access)
    - Free tier exists, even if rate-limited or with paid upgrade options
    - Free sandbox/testing access, even if production requires payment
    - Agreement to terms of service grants access
    - Email verification or automatic account approval grants access
  - Code 0 (Closed) if:
    - Must pay or contact sales to get ANY access
    - Manual application/approval process required (e.g., "apply for access", staff review, waitlist)
    - Portal exists but ALL documentation/APIs behind a partner program or NDA
  - COMMON ERRORS TO AVOID:
    - The key distinction is SELF-SERVICE vs GATEKEPT access
    - OPEN=1: Developer signs up and gets access automatically (even if they must verify email or agree to terms)
    - OPEN=0: Developer must APPLY and WAIT for a human/manual review, or MUST PAY before getting any access
    - A free tier with rate limits + a paid option for higher limits = OPEN=1 (free access exists)
    - Enterprise options EXISTING does not make it closed if core access is free (still OPEN=1)
    - If portal is behind a login wall and NO pricing/tier/access info is visible, code OPEN=1 (assume free self-service registration)
    - DO NOT code OPEN=0 just because a login page exists — a login page alone means free registration (OPEN=1)
- **OPEN_lang** (Count): Natural languages for access documentation.
- **OPEN_lang_list** (List): Natural languages.

## LANGUAGE RECORDING RULES

For each resource type with _lang columns, use this PRIORITY ORDER:

1. **FIRST: Check for language switcher/selector** (PREFERRED SOURCE)
   - Look for dropdown menus, globe icons, flag icons on main portal page
   - If found, record ALL languages shown in the switcher
   - This is the most reliable count of available languages

2. **SECOND: Check for country-specific domains** (if no switcher)
   - Look for .de, .fr, .jp, .com.br, /es/, /zh/ in URLs
   - Country domains imply language availability

3. **THIRD: Count confirmed translated content** (fallback)
   - If no switcher and no country domains, only count languages with actual translated content found
   - Do not assume translations exist without evidence

4. **Record languages consistently**:
   - Use semicolon separator: "English; Japanese; German"
   - Record for EACH resource type separately (SDK_lang, COM_lang, etc.)
   - Even if same language appears in multiple resources, record it in each

Common languages: English, Spanish, French, German, Italian, Portuguese, Japanese, Chinese, Korean, Russian, Arabic, Turkish, Thai, Vietnamese, Indonesian, Dutch, Polish, Swedish, Norwegian, Danish, Finnish, Czech, Hungarian, Romanian, Greek, Hebrew, Hindi

## VALID PROGRAMMING LANGUAGES (Codebook Reference Index)

ONLY count and list these programming languages for SDK_prog_lang_list, GIT_prog_lang_list, and BUG_prog_lang_list:

Ada, Apex, Assembly, Bash/Shell, C, C#, C++, Clojure, Cobol, Crystal, Dart, Delphi, Elixir, Erlang, F#, Fortran, GDScript, Go, Groovy, Haskell, HTML/CSS, Java, JavaScript, Julia, Kotlin, Lisp, Lua, MATLAB, MicroPython, Nim, Objective-C, OCaml, Perl, PHP, PowerShell, Prolog, Python, R, Ruby, Rust, Scala, Solidity, SQL, Swift, TypeScript, VBA, Visual Basic, Zephyr

**NOT Programming Languages (DO NOT list):**
- Game engines/platforms: Unity, Unreal, Unreal Engine, Native
- Mobile platforms: iOS, Android, Flutter, React Native, Xamarin
- Frameworks/runtimes: .NET, Node.js, Spring, Django, Rails, Express
- Build tools: CMake, Gradle, Maven, npm, pip
- Markup only: XML, JSON, YAML, Markdown (unless HTML/CSS which is valid)

**Mapping rules:**
- If SDK says "Unity" → record C# (Unity uses C#)
- If SDK says "Unreal" → record C++ (Unreal uses C++)
- If SDK says "Node.js" → record JavaScript
- If SDK says ".NET" → record C# or F# as applicable
- If SDK says "Android SDK" → record Java and/or Kotlin
- If SDK says "iOS SDK" → record Swift and/or Objective-C

## CRITICAL RULES

1. Code ONLY what is explicitly documented - do not infer
2. AI agent docs/SDKs count ONLY in AI_AGENT, NOT in DOCS/SDK
3. GitHub counts ONLY in GIT, NOT in COM
4. All _list variables use semicolon separator
5. **BINARY VARIABLES MUST BE EXACTLY 0 OR 1** - These variables are presence/absence ONLY:
   DEVP, DOCS, SDK, BUG, STAN, AI_MODEL, AI_AGENT, AI_ASSIST, AI_DATA, AI_MKT,
   GIT, MON, ROLE, DATA, STORE, CERT, OPEN, and all COM_*, EVENT_*, SPAN_* sub-components.
   - 0 = NOT present/found
   - 1 = Present/found (regardless of how many)
   - NEVER use counts like 2, 5, 156 for these variables
6. Provide evidence for key coded values

## CALIBRATION EXAMPLES

Below are three correctly coded platforms to calibrate your coding. They include positive and negative examples for key governance variables (ROLE, DATA, OPEN, METH).

**Example 1: Activision Blizzard Inc (REGISTRATION) — POSITIVE example for ROLE, DATA, METH**
Key codings: API=1, METH=2, DEVP=1, DOCS=1, SDK=0, BUG=0, STAN=1, AI_MODEL=0, AI_AGENT=0, AI_ASSIST=0, AI_DATA=0, AI_MKT=0, COM_forum=1, COM_help_support=1, GIT=1, MON=0, EVENT=0, SPAN=0, ROLE=1, DATA=1, STORE=0, CERT=0, OPEN=1
Reasoning:
- API=1 because API documentation exists (Battle.net API with game data endpoints).
- METH=2 because GET and POST endpoints are documented for game data and profile data.
- STAN=1 because OAuth 2.0 (IETF RFC 6749) is used for authentication.
- ROLE=1 because OAuth authentication requires developers to register, obtain client credentials, and use scoped access (different OAuth scopes grant different data access levels).
- DATA=1 because Blizzard Developer API Terms of Use specifies how developers may use data obtained through APIs, and the forum has a Data Protection Notice with FAQ.
- GIT=1 because GitHub repositories are referenced (community SDKs linked from forums).
- COM_help_support=1 because support page exists linked from the portal.
- OPEN=1 because registration is free with no payment required — developers can self-service access the platform.

**Example 2: HTC Corp (PUBLIC) — POSITIVE example for DATA, OPEN; NEGATIVE for ROLE**
Key codings: API=1, METH=2, DEVP=1, DOCS=1, SDK=1, BUG=1, STAN=1, AI_MODEL=0, AI_AGENT=0, AI_ASSIST=0, AI_DATA=0, AI_MKT=0, COM_social_media=1, COM_forum=1, COM_blog=1, COM_help_support=1, COM_Discord=1, GIT=1, MON=0, EVENT=1, SPAN=0, ROLE=0, DATA=1, STORE=1, CERT=0, OPEN=1
Reasoning:
- SDK=1 because downloadable Wave SDK and OpenXR SDK provided for Unity and Unreal.
- STAN=1 because OpenXR (Khronos Group standard) is used for VR interoperability.
- ROLE=0 because no documentation showing different permission levels — all developers get same access.
- DATA=1 because developer terms of use specify conditions for handling user data from the VR platform.
- OPEN=1 because free SDK access exists — developers can self-service access the platform's resources.
- COM channels: social media, forum, blog, help/support, Discord.

**Example 3: Hi-Rez Studios Inc (REGISTRATION) — NEGATIVE example for OPEN (application required = Closed)**
Key codings: API=1, METH=1, DEVP=1, DOCS=1, SDK=0, BUG=0, STAN=0, AI_MODEL=0, AI_AGENT=0, AI_ASSIST=0, AI_DATA=0, AI_MKT=0, COM_forum=0, COM_help_support=0, GIT=0, MON=0, EVENT=0, SPAN=0, ROLE=0, DATA=0, STORE=0, CERT=0, OPEN=0
Reasoning:
- DEVP=1 because a developer API guide exists describing the Smite/Paladins API.
- API=1 because game data APIs are documented (player stats, match history, god/champion data).
- METH=1 because GET method is documented for API endpoints.
- OPEN=0 because developers must APPLY for access and receive approved credentials (Developer ID and Authentication Key) — this is a manual application/approval process, NOT free self-service registration. "Apply for access" = OPEN=0 (Closed).
- Note: A login page alone with no other info would be OPEN=1 (Open). But explicit "apply and wait for approval" language means OPEN=0 (Closed).

## OUTPUT FORMAT

Return ONLY valid JSON in this exact structure (no markdown, no explanation):
{{
  "platform_id": "{platform_id}",
  "platform_name": "{platform_name}",
  "analysis_date": "{date}",
  "coder": "ChatGPT",
  "PLAT": "{plat_status}",
  "PLAT_Notes": "",
  "platform_controls": {{
    "AGE": 0,
    "API_YEAR": ""
  }},
  "application": {{
    "API": 0,
    "METH": 0, "METH_list": ""
  }},
  "development": {{
    "DEVP": 0, "DOCS": 0,
    "SDK": 0, "SDK_lang": 0, "SDK_lang_list": "", "SDK_prog_lang": 0, "SDK_prog_lang_list": "",
    "BUG": 0, "BUG_types": "", "BUG_prog_lang_list": "",
    "STAN": 0, "STAN_list": ""
  }},
  "ai": {{
    "AI_MODEL": 0, "AI_MODEL_types": "",
    "AI_AGENT": 0, "AI_AGENT_platforms": "",
    "AI_ASSIST": 0, "AI_ASSIST_tools": "",
    "AI_DATA": 0, "AI_DATA_protocols": "",
    "AI_MKT": 0, "AI_MKT_type": ""
  }},
  "social": {{
    "COM_lang": 0, "COM_lang_list": "",
    "COM_social_media": 0, "COM_forum": 0, "COM_blog": 0, "COM_help_support": 0,
    "COM_live_chat": 0, "COM_Slack": 0, "COM_Discord": 0, "COM_stackoverflow": 0,
    "COM_training": 0, "COM_FAQ": 0,
    "GIT": 0, "GIT_url": "", "GIT_lang": 0, "GIT_lang_list": "", "GIT_prog_lang": 0, "GIT_prog_lang_list": "",
    "MON": 0,
    "EVENT": 0, "EVENT_webinars": 0, "EVENT_virtual": 0, "EVENT_in_person": 0,
    "EVENT_conference": 0, "EVENT_hackathon": 0, "EVENT_other": 0, "EVENT_countries": "",
    "SPAN": 0, "SPAN_internal": 0, "SPAN_communities": 0, "SPAN_external": 0,
    "SPAN_lang": 0, "SPAN_lang_list": "", "SPAN_countries": ""
  }},
  "governance": {{
    "ROLE": 0, "ROLE_lang": 0, "ROLE_lang_list": "",
    "DATA": 0, "DATA_lang": 0, "DATA_lang_list": "",
    "STORE": 0, "STORE_lang": 0, "STORE_lang_list": "",
    "CERT": 0, "CERT_lang": 0, "CERT_lang_list": "",
    "OPEN": 0, "OPEN_lang": 0, "OPEN_lang_list": ""
  }},
  "moderators": {{
    "home_primary_lang": "", "language_notes": ""
  }},
  "evidence": {{
    "API_evidence": "",
    "SDK_evidence": "",
    "AI_evidence": "",
    "language_evidence": ""
  }},
  "pages_analyzed": 0,
  "coding_notes": ""
}}

## CONTENT STRUCTURE GUIDE

The content below is scraped from a developer portal and may include:

1. **EXTERNAL LINKS SECTION** (at the top): URLs extracted from the site header, footer, and
   navigation menus. These are critical for coding COM variables — look here for social media
   links (Twitter/X, LinkedIn, YouTube), blog URLs, support/help links, forum links, Discord
   and Slack invite links, and StackOverflow tags. These links represent what a developer would
   see in the site navigation.

2. **PAGE CONTENT**: The full text of each scraped page, separated by page headers. Pages from
   GitHub repositories may contain README files with references to standards (STAN), programming
   languages (SDK_prog_lang, GIT_prog_lang), and testing tools (BUG). Pay attention to GitHub
   content for these variables.

3. **NAVIGATION AND FOOTER TEXT**: Headers and footers are repeated across pages and often
   contain links to blog, support, community, events, partner programs (MON), and training
   resources. These repetitions confirm the presence of COM resources.

===== DEVELOPER PORTAL CONTENT =====
{content}
===== END CONTENT =====

Return ONLY the JSON output, no additional text.'''


# ============================================================================
# CODER CLASS
# ============================================================================

class ChatGPTBRCoder:
    """Codes boundary resources using OpenAI API."""

    def __init__(self, output_dir: str, verbose: bool = True, max_content_chars: int = 200000):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose
        # ChatGPT-4o has 128K token context window (~512K chars at ~4 chars/token)
        # After deducting system prompt + coding prompt (~20K chars) and response space (~8K chars),
        # safe content limit is ~200K chars. This covers 79/115 platform firms (69%) fully.
        # Post-dedup analysis (Feb 2026): median platform = 122K chars, 75th pct = 253K chars.
        # Use --max-content flag to override for rate-limited API tiers or symmetric IRR testing.
        self.max_content_chars = max_content_chars
        self.client = OpenAI()

    def log(self, msg: str):
        if self.verbose:
            print(msg)

    def code_platform(self, platform_id: str, platform_name: str, plat_status: str,
                      portal_url: str, content: str = None) -> dict:
        """Code a single platform's boundary resources."""

        result = {
            'platform_id': platform_id,
            'platform_name': platform_name,
            'analysis_date': datetime.now().isoformat(),
            'coder': 'ChatGPT',
            'PLAT': plat_status,
            'auto_coded': False,
            'success': False,
            'error': None
        }

        # Auto-zero for PLAT = NONE
        if plat_status == 'NONE':
            self.log(f"  Auto-zero coding (PLAT=NONE)")
            result.update(AUTO_ZERO_RESULT)
            result['auto_coded'] = True
            result['success'] = True
            result['coding_notes'] = "Auto-coded with zeros - no developer portal (PLAT=NONE)"
            return result

        # If no content, return error
        if not content:
            result['error'] = "No content provided for coding"
            return result

        # Build prompt - truncate content to max_content_chars (set in __init__ or via --max-content)
        max_chars = self.max_content_chars
        truncated_content = content[:max_chars]
        if len(content) > max_chars:
            truncated_content += f"\n\n[TRUNCATED - Content exceeded {max_chars:,} characters]"

        prompt = CODING_PROMPT.format(
            platform_name=platform_name,
            platform_id=platform_id,
            plat_status=plat_status,
            portal_url=portal_url or "N/A",
            date=datetime.now().strftime("%Y-%m-%d"),
            content=truncated_content
        )

        try:
            self.log(f"  Sending to OpenAI API ({MODEL})...")

            response = self.client.chat.completions.create(
                model=MODEL,
                max_tokens=MAX_TOKENS,
                temperature=0,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"}  # Force JSON output
            )

            response_text = response.choices[0].message.content.strip()

            # Parse JSON
            coding_result = json.loads(response_text)
            result.update(coding_result)
            result['success'] = True

        except json.JSONDecodeError as e:
            result['error'] = f"JSON parse error: {str(e)}"
            result['raw_response'] = response_text[:1000] if 'response_text' in dir() else None
        except Exception as e:
            result['error'] = f"Error: {str(e)}"

        return result

    def code_from_tracker(self, scraped_dir: str, tracker_file: str,
                          limit: int = None, dry_run: bool = False,
                          platforms: list = None) -> dict:
        """Code all platforms from tracker file."""

        scraped_path = Path(scraped_dir)

        # Read tracker file
        if tracker_file.endswith('.csv'):
            df = pd.read_csv(tracker_file)
        else:
            df = pd.read_excel(tracker_file, header=1)

        # Filter by specific platform IDs if provided
        if platforms:
            df = df[df['platform_ID'].isin(platforms)]
            self.log(f"Filtering to {len(df)} specified platforms: {platforms}")

        if limit:
            df = df.head(limit)

        total = len(df)
        self.log(f"\n{'='*60}")
        self.log(f"CHATGPT/OPENAI BOUNDARY RESOURCE CODER")
        self.log(f"{'='*60}")
        self.log(f"Model: {MODEL}")
        self.log(f"Tracker file: {tracker_file}")
        self.log(f"Scraped content: {scraped_dir}")
        self.log(f"Platforms to code: {total}")
        self.log(f"Output directory: {self.output_dir}")

        if dry_run:
            self.log(f"\n🔍 DRY RUN - Not actually coding\n")
            for _, row in df.iterrows():
                plat = row.get('PLAT', 'UNKNOWN')
                action = "Auto-zero" if plat == 'NONE' else "Full coding"
                self.log(f"  {row['platform_name']}: {plat} → {action}")
            return {'dry_run': True, 'platforms': total}

        self.log(f"{'='*60}\n")

        # Code each platform
        results = {
            'coding_date': datetime.now().isoformat(),
            'model': MODEL,
            'tracker_file': tracker_file,
            'output_dir': str(self.output_dir),
            'total_platforms': total,
            'successful': 0,
            'auto_coded': 0,
            'failed': 0,
            'platforms': []
        }

        for idx, (_, row) in enumerate(df.iterrows(), 1):
            platform_id = row['platform_ID']
            platform_name = row['platform_name']
            plat_status = row.get('PLAT', 'UNKNOWN')
            portal_url = row.get('developer_portal_url', '')

            self.log(f"\n[{idx}/{total}] {platform_name} ({plat_status})")
            self.log("-" * 60)

            # Find scraped content
            content = None
            if plat_status != 'NONE':
                # Look for combined content file
                import re
                safe_name = re.sub(r'[^\w\-_]', '_', platform_name)
                content_file = scraped_path / f"{platform_id}_{safe_name}" / "COMBINED_CONTENT.txt"

                if content_file.exists():
                    content = content_file.read_text(encoding='utf-8')
                    self.log(f"  Found scraped content: {len(content):,} chars")
                else:
                    self.log(f"  ⚠️  No scraped content found: {content_file}")

            # Code the platform
            result = self.code_platform(
                platform_id=platform_id,
                platform_name=platform_name,
                plat_status=plat_status,
                portal_url=portal_url,
                content=content
            )

            results['platforms'].append(result)

            # Save individual result
            result_file = self.output_dir / f"{platform_id}_chatgpt.json"
            result_file.write_text(json.dumps(result, indent=2), encoding='utf-8')

            if result['success']:
                if result.get('auto_coded'):
                    results['auto_coded'] += 1
                    self.log(f"  ✅ Auto-coded (PLAT=NONE)")
                else:
                    results['successful'] += 1
                    self.log(f"  ✅ Successfully coded")
                    # Adaptive rate limit based on content size
                    if idx < total:
                        content_len = len(content) if content else 0
                        if content_len > 50000:
                            delay = 60
                        elif content_len > 20000:
                            delay = 30
                        else:
                            delay = 10
                        self.log(f"  ⏳ Waiting {delay}s for rate limit ({content_len:,} chars)...")
                        time.sleep(delay)
            else:
                results['failed'] += 1
                self.log(f"  ❌ Failed: {result.get('error', 'Unknown error')}")

        # Save combined results
        summary_file = self.output_dir / "chatgpt_coding_summary.json"
        summary_file.write_text(json.dumps(results, indent=2), encoding='utf-8')

        # Export to CSV for CODE_BOOK import
        self._export_to_csv(results)

        # Print summary
        self.log(f"\n{'='*60}")
        self.log("CODING COMPLETE")
        self.log(f"{'='*60}")
        self.log(f"✅ Successfully coded: {results['successful']}")
        self.log(f"🔄 Auto-coded (PLAT=NONE): {results['auto_coded']}")
        self.log(f"❌ Failed: {results['failed']}")
        self.log(f"📁 Output: {self.output_dir}")
        self.log(f"{'='*60}\n")

        return results

    def _export_to_csv(self, results: dict):
        """Export coding results to CSV for CODE_BOOK import."""
        rows = []

        for platform in results['platforms']:
            if not platform.get('success'):
                continue

            row = {
                'platform_ID': platform.get('platform_id'),
                'platform_name': platform.get('platform_name'),
                'PLAT': platform.get('PLAT'),
                'PLAT_Notes': platform.get('PLAT_Notes', ''),
                'analysis_date': platform.get('analysis_date'),
                'coder': 'ChatGPT',
                'auto_coded': platform.get('auto_coded', False)
            }

            # Flatten nested dictionaries
            for category in ['platform_controls', 'application', 'development', 'ai', 'social', 'governance', 'moderators']:
                if category in platform:
                    for key, value in platform[category].items():
                        row[key] = value

            row['pages_analyzed'] = platform.get('pages_analyzed', 0)
            row['coding_notes'] = platform.get('coding_notes', '')
            rows.append(row)

        if rows:
            csv_df = pd.DataFrame(rows)
            csv_file = self.output_dir / "chatgpt_coding_results.csv"
            csv_df.to_csv(csv_file, index=False)
            self.log(f"  Exported CSV: {csv_file}")


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Code boundary resources using OpenAI/ChatGPT API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --output chatgpt_results/
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --limit 5  # Test on 5
    python3 chatgpt_coder.py scraped_content/ tracker.xlsx --dry-run  # Preview
        """
    )
    parser.add_argument('scraped_dir', help='Directory with scraped content (from page_scraper.py)')
    parser.add_argument('tracker_file', help='Search tracker file with PLAT coding')
    parser.add_argument('--output', '-o', default='chatgpt_results', help='Output directory')
    parser.add_argument('--limit', '-l', type=int, help='Limit number of platforms to code')
    parser.add_argument('--platforms', '-p', help='Comma-separated list of platform IDs to code (e.g., VG26,VG28,VG29)')
    parser.add_argument('--max-content', type=int, default=None,
                        help='Override max content chars (default: 200000). Use lower value for symmetric IRR testing.')
    parser.add_argument('--dry-run', action='store_true', help='Preview without coding')
    parser.add_argument('--quiet', '-q', action='store_true', help='Minimal output')

    args = parser.parse_args()

    # Check API key
    if not os.environ.get('OPENAI_API_KEY'):
        print("ERROR: OPENAI_API_KEY environment variable not set")
        print("Run: export OPENAI_API_KEY='your-api-key'")
        sys.exit(1)

    if not os.path.exists(args.tracker_file):
        print(f"ERROR: Tracker file not found: {args.tracker_file}")
        sys.exit(1)

    max_chars = args.max_content if args.max_content else 200000
    if args.max_content:
        print(f"Using custom max content chars: {max_chars:,}")

    coder = ChatGPTBRCoder(
        output_dir=args.output,
        verbose=not args.quiet,
        max_content_chars=max_chars
    )

    # Parse platforms if provided
    platforms_list = None
    if args.platforms:
        platforms_list = [p.strip() for p in args.platforms.split(',')]

    results = coder.code_from_tracker(
        scraped_dir=args.scraped_dir,
        tracker_file=args.tracker_file,
        limit=args.limit,
        dry_run=args.dry_run,
        platforms=platforms_list
    )

    if not args.dry_run:
        print(f"\nNext steps:")
        print(f"  1. Compare with Claude results for IRR")
        print(f"  2. Run: python3 irr_calculator.py claude_results/ {args.output}/")


if __name__ == "__main__":
    main()
