# Complete Beginner Guide: Video Game Developer Portal Classification
## Using Claude Batch API on macOS Sequoia

**Created for:** Heather's PhD Dissertation Research  
**macOS Version:** Sequoia 15.3.1  
**Skill Level Required:** Complete Beginner  
**Estimated Setup Time:** 30-45 minutes  
**Estimated Cost:** $3-5 for 158 companies

---

# TABLE OF CONTENTS

1. [Part 1: Check What You Already Have](#part-1-check-what-you-already-have)
2. [Part 2: Install Python (if needed)](#part-2-install-python-if-needed)
3. [Part 3: Set Up Your Project Folder](#part-3-set-up-your-project-folder)
4. [Part 4: Get Your Anthropic API Key](#part-4-get-your-anthropic-api-key)
5. [Part 5: Install Required Software](#part-5-install-required-software)
6. [Part 6: Prepare Your Data](#part-6-prepare-your-data)
7. [Part 7: Submit the Batch](#part-7-submit-the-batch)
8. [Part 8: Check Batch Status](#part-8-check-batch-status)
9. [Part 9: Download Results](#part-9-download-results)
10. [Part 10: Troubleshooting](#part-10-troubleshooting)

---

# PART 1: Check What You Already Have

## Step 1.1: Open Terminal

Terminal is the app where you'll type commands. Here's how to open it:

**Method 1: Using Spotlight**
1. Press `Command (⌘) + Spacebar` on your keyboard
2. Type: `Terminal`
3. Press `Enter` or click on "Terminal" in the results

**Method 2: Using Finder**
1. Open Finder
2. Click "Applications" in the left sidebar
3. Open the "Utilities" folder
4. Double-click "Terminal"

You should see a window with text that looks something like:
```
yourusername@your-mac ~ %
```

This is called the "command prompt" - it's waiting for you to type commands.

## Step 1.2: Check if Python is Already Installed

macOS often comes with Python pre-installed. Let's check.

**Type this command and press Enter:**
```bash
python3 --version
```

**What you might see:**

✅ **Good result (Python is installed):**
```
Python 3.11.6
```
(or any version 3.9 or higher)

→ If you see this, SKIP to [Part 3](#part-3-set-up-your-project-folder)

❌ **Bad result (Python not installed):**
```
command not found: python3
```
or
```
No developer tools were found
```

→ If you see this, continue to [Part 2](#part-2-install-python-if-needed)

---

# PART 2: Install Python (if needed)

There are two ways to install Python on Mac. I recommend Method A for beginners.

## Method A: Download from Python.org (Recommended for Beginners)

### Step 2.1: Download Python

1. Open Safari (or any web browser)
2. Go to: **https://www.python.org/downloads/**
3. Click the big yellow button that says **"Download Python 3.x.x"**
   (The exact number doesn't matter as long as it starts with 3)
4. A file called `python-3.x.x-macos11.pkg` will download

### Step 2.2: Install Python

1. Open your **Downloads** folder
2. Double-click the file `python-3.x.x-macos11.pkg`
3. An installer window will open
4. Click **Continue** through the introduction
5. Click **Continue** on the license (then click **Agree**)
6. Click **Install**
7. Enter your Mac password when prompted
8. Wait for installation to complete
9. Click **Close**

### Step 2.3: Verify Installation

1. **Close Terminal completely** (Command+Q)
2. **Reopen Terminal** (Command+Space, type "Terminal", Enter)
3. Type this command:
```bash
python3 --version
```

You should now see:
```
Python 3.x.x
```

🎉 **Python is now installed!**

---

## Method B: Using Homebrew (Alternative - More Technical)

Only use this method if Method A didn't work or you prefer using Homebrew.

### Step 2.4: Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts (you'll need to enter your Mac password).

### Step 2.5: Install Python via Homebrew

```bash
brew install python
```

### Step 2.6: Verify

```bash
python3 --version
```

---

# PART 3: Set Up Your Project Folder

We'll create a dedicated folder for this project to keep everything organized.

## Step 3.1: Create Project Folder

In Terminal, type these commands **one at a time**, pressing Enter after each:

```bash
cd ~/Documents
```
(This navigates to your Documents folder)

```bash
mkdir dissertation_batch_api
```
(This creates a new folder called "dissertation_batch_api")

```bash
cd dissertation_batch_api
```
(This moves into that new folder)

## Step 3.2: Verify You're in the Right Place

```bash
pwd
```
(This shows your current location)

You should see:
```
/Users/yourusername/Documents/dissertation_batch_api
```

## Step 3.3: Open This Folder in Finder (Optional but Helpful)

```bash
open .
```
(This opens the current folder in Finder so you can see files visually)

---

# PART 4: Get Your Anthropic API Key

An API key is like a password that lets your scripts access Claude.

## Step 4.1: Create an Anthropic Account

1. Open your web browser
2. Go to: **https://console.anthropic.com/**
3. Click **"Sign Up"** (or "Sign In" if you already have an account)
4. Create an account using:
   - Google account, OR
   - Email and password

## Step 4.2: Add Billing Information

You need to add a payment method before you can use the API.

1. Once logged in, look at the left sidebar
2. Click **"Billing"** or **"Plans & Billing"**
3. Click **"Add Payment Method"**
4. Enter your credit card information
5. Add credits to your account:
   - Click **"Add Credits"** or **"Buy Credits"**
   - Start with **$10-20** (you'll only use ~$3-5 for this project)
   - The rest stays in your account for future use

## Step 4.3: Create an API Key

1. In the left sidebar, click **"API Keys"**
2. Click **"Create Key"** (or "+ Create Key")
3. Give it a name like: `dissertation-research`
4. Click **"Create"**
5. **IMPORTANT:** You'll see your API key displayed. It looks like:
   ```
   sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
6. **Click the copy button** to copy it
7. **SAVE THIS KEY SOMEWHERE SAFE** (like a password manager or a secure note)
   - You will NEVER see this key again after you close this page
   - If you lose it, you'll have to create a new one

## Step 4.4: Store Your API Key Securely

We'll save your API key so the scripts can use it without you typing it every time.

In Terminal (make sure you're in your project folder), type:

```bash
echo 'export ANTHROPIC_API_KEY="YOUR_KEY_HERE"' >> ~/.zshrc
```

**Replace `YOUR_KEY_HERE` with your actual API key.** For example:
```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-api03-xxxxx..."' >> ~/.zshrc
```

Then reload your terminal configuration:
```bash
source ~/.zshrc
```

Verify it's set:
```bash
echo $ANTHROPIC_API_KEY
```

You should see your API key printed (or at least the beginning of it).

---

# PART 5: Install Required Software

We need to install the Anthropic Python library that lets us communicate with Claude.

## Step 5.1: Upgrade pip (Python's Package Installer)

```bash
python3 -m pip install --upgrade pip
```

You might see some output - that's normal.

## Step 5.2: Install Anthropic Library

```bash
pip3 install anthropic
```

You should see output ending with something like:
```
Successfully installed anthropic-0.40.0
```

## Step 5.3: Verify Installation

```bash
python3 -c "import anthropic; print('Anthropic installed successfully!')"
```

You should see:
```
Anthropic installed successfully!
```

If you see an error, try:
```bash
pip3 install --user anthropic
```

---

# PART 6: Prepare Your Data

## Step 6.1: Copy Your Data File

You need to copy your `vg_portal_search_tracker_WORKING.csv` file to the project folder.

**Option A: Using Finder**
1. Find your `vg_portal_search_tracker_WORKING.csv` file
2. Copy it (Command+C)
3. Open your project folder: Documents → dissertation_batch_api
4. Paste it (Command+V)

**Option B: Using Terminal** (if you know where the file is)
```bash
cp /path/to/your/vg_portal_search_tracker_WORKING.csv ~/Documents/dissertation_batch_api/
```

## Step 6.2: Verify the File is There

```bash
ls -la
```

You should see `vg_portal_search_tracker_WORKING.csv` in the list.

---

# PART 7: Submit the Batch

## Step 7.1: Download the Scripts

The scripts I've created should be in your project folder. Verify:

```bash
ls *.py
```

You should see:
- `01_submit_batch.py`
- `02_check_status.py`
- `03_download_results.py`

If not, you'll need to create them (copy from the files I provided).

## Step 7.2: Do a Test Run First (Dry Run)

Before spending any money, let's test with just 2 companies:

```bash
python3 01_submit_batch.py --dry-run --limit 2
```

This will show you what WOULD be submitted without actually doing it.

Review the output. Does it look correct?

## Step 7.3: Submit a Small Test Batch (5 companies)

Let's test with real API calls but just 5 companies (~$0.15):

```bash
python3 01_submit_batch.py --limit 5
```

**What happens:**
1. Script reads your CSV file
2. Creates requests for 5 PENDING companies
3. Submits to Anthropic
4. Returns a batch ID

**You'll see output like:**
```
=== BATCH SUBMISSION ===
Reading companies from: vg_portal_search_tracker_WORKING.csv
Found 158 PENDING companies
Limiting to 5 companies for this batch

Creating batch request...
Batch submitted successfully!

╔═══════════════════════════════════════════════════════════════╗
║  BATCH ID: msgbatch_01ABC123XYZ...                            ║
║                                                                ║
║  SAVE THIS ID! You need it to check status and get results.  ║
╚═══════════════════════════════════════════════════════════════╝

Batch ID saved to: batch_id.txt
Status: in_progress
Estimated completion: 1-24 hours (usually 2-6 hours for small batches)
```

## Step 7.4: Save the Batch ID

The script automatically saves it to `batch_id.txt`, but also **write it down** or save it somewhere else just in case.

## Step 7.5: Submit the Full Batch (After Test Succeeds)

Once you've verified the test batch works, submit all remaining companies:

```bash
python3 01_submit_batch.py
```

This submits all PENDING companies (up to 158).

---

# PART 8: Check Batch Status

Batches take time to process. Here's how to check progress.

## Step 8.1: Check Status

```bash
python3 02_check_status.py
```

(It automatically reads the batch ID from `batch_id.txt`)

**Or specify the ID manually:**
```bash
python3 02_check_status.py --batch-id msgbatch_01ABC123XYZ
```

## Step 8.2: Understanding Status Output

```
=== BATCH STATUS ===
Batch ID: msgbatch_01ABC123XYZ
Status: in_progress

Progress:
  ✓ Succeeded: 45
  ⏳ Processing: 113
  ✗ Errored: 0
  ⏹ Canceled: 0
  ⏰ Expired: 0

Total: 158 requests
Progress: 28% complete

Estimated time remaining: 2-4 hours
```

## Step 8.3: Wait for Completion

- Check every 30-60 minutes
- Status will change from `in_progress` to `ended`
- Typical completion time: 2-6 hours for 158 requests

**When complete, you'll see:**
```
=== BATCH STATUS ===
Batch ID: msgbatch_01ABC123XYZ
Status: ended ✓

Progress:
  ✓ Succeeded: 158
  ✗ Errored: 0

🎉 BATCH COMPLETE! Run 03_download_results.py to get your data.
```

---

# PART 9: Download Results

## Step 9.1: Download and Process Results

```bash
python3 03_download_results.py
```

**What happens:**
1. Downloads all results from Anthropic
2. Parses each company's classification
3. Updates your CSV file
4. Creates a summary report

## Step 9.2: Review Output

```
=== DOWNLOADING RESULTS ===
Batch ID: msgbatch_01ABC123XYZ
Downloading 158 results...

Processing results...
  ✓ Microsoft: PUBLIC
  ✓ Sony: PUBLIC
  ✓ Nintendo: REGISTRATION
  ✓ Epic Games: PUBLIC
  ... (continues for all companies)

=== SUMMARY ===
Total processed: 158

Classification breakdown:
  PUBLIC: 45 (28%)
  REGISTRATION: 32 (20%)
  RESTRICTED: 12 (8%)
  NONE: 69 (44%)

Results saved to: vg_portal_search_tracker_WORKING.csv
Detailed log saved to: batch_results_log.json
Summary saved to: batch_summary.txt
```

## Step 9.3: Check Your Updated CSV

Open `vg_portal_search_tracker_WORKING.csv` to see the results. Each company should now have:
- `PLAT` column filled in
- `PLAT_Notes` with details
- `developer_portal_url` if found
- `search_status` changed to "COMPLETED"

---

# PART 10: Troubleshooting

## Problem: "command not found: python3"

**Solution:** Python isn't installed or not in your PATH.
1. Close Terminal
2. Reopen Terminal
3. Try again
4. If still failing, reinstall Python using Part 2

## Problem: "ModuleNotFoundError: No module named 'anthropic'"

**Solution:** Anthropic library not installed properly.
```bash
pip3 install --user anthropic
```

## Problem: "AuthenticationError" or "Invalid API Key"

**Solution:** Your API key isn't set correctly.
1. Check if it's set:
   ```bash
   echo $ANTHROPIC_API_KEY
   ```
2. If empty, set it again:
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ```
3. Or pass it directly:
   ```bash
   python3 01_submit_batch.py --api-key "your-key-here"
   ```

## Problem: "InsufficientCredits" or "Payment Required"

**Solution:** Add credits to your Anthropic account.
1. Go to console.anthropic.com
2. Click Billing
3. Add more credits

## Problem: Batch shows "expired" status

**Solution:** The batch took longer than 24 hours. This is rare, but if it happens:
1. Check which companies weren't processed
2. Resubmit just those companies

## Problem: "Permission denied" when running scripts

**Solution:** Make the scripts executable:
```bash
chmod +x *.py
```

## Problem: Can't find my project folder

**Solution:**
```bash
cd ~/Documents/dissertation_batch_api
```

---

# QUICK REFERENCE CARD

Keep this handy for future use:

```
┌─────────────────────────────────────────────────────────────────┐
│  QUICK COMMANDS                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Go to project folder:                                          │
│    cd ~/Documents/dissertation_batch_api                        │
│                                                                  │
│  Submit batch (dry run):                                        │
│    python3 01_submit_batch.py --dry-run                         │
│                                                                  │
│  Submit batch (real):                                           │
│    python3 01_submit_batch.py                                   │
│                                                                  │
│  Check status:                                                  │
│    python3 02_check_status.py                                   │
│                                                                  │
│  Download results:                                              │
│    python3 03_download_results.py                               │
│                                                                  │
│  View your API key:                                             │
│    echo $ANTHROPIC_API_KEY                                      │
│                                                                  │
│  Check Anthropic console:                                       │
│    https://console.anthropic.com/                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

# WHAT'S NEXT?

After completing Video Games:

1. **Review results** - Check accuracy of classifications
2. **Human verification** - Spot-check 10-20 companies manually
3. **Scale up** - Use same scripts for other industries
4. **Full data collection** - For PUBLIC/REGISTRATION companies, do detailed BR coding

---

**Need help?** Save any error messages and bring them back to our Claude conversation!
