================================================================================
           STUDENT AGENCY MANAGER (AGENCY HEAD) - USB PEN DRIVE PACKAGE
================================================================================

This folder is configured to be copied onto any USB Pen Drive and run/installed
on ANY other computer (Windows or macOS) without requiring an internet web portal.

--------------------------------------------------------------------------------
1. HOW TO PUT ON YOUR PEN DRIVE:
--------------------------------------------------------------------------------
1. Plug your USB Pen Drive into this computer.
2. Copy this entire "pen_drive_package" folder (or copy everything inside it)
   onto your USB Pen Drive.
3. Unplug the pen drive and take it to any computer.

--------------------------------------------------------------------------------
2. HOW TO RUN & INSTALL ON ANY WINDOWS COMPUTER:
--------------------------------------------------------------------------------
1. Plug the pen drive into the Windows computer.
2. Open the pen drive folder.
3. Double-click:
     >> Launch_Agency_Head_Windows.bat <<

   What will happen:
   - It will automatically launch Agency Head as a standalone Web App window
     using Microsoft Edge or Google Chrome (in app mode without browser tabs).
   - In the top bar or inside the sidebar, click "Install" or "Install App".
   - The app will now be permanently installed on the Windows Desktop & Start Menu!

--------------------------------------------------------------------------------
3. HOW TO RUN & INSTALL ON ANY MAC (macOS):
--------------------------------------------------------------------------------
Option A (Native Mac Desktop App):
1. Open the "macOS_App" folder on the pen drive.
2. Drag "agency_head.app" into the Mac's Applications folder (or double-click to run).

Option B (Web App / PWA):
1. Double-click:
     >> Launch_Agency_Head_Mac.command <<
2. The Web App will open in your browser or as a standalone app window.
3. Click "Install App" to add it to your Mac Dock / Launchpad.

--------------------------------------------------------------------------------
4. APP ROLES & SYSTEM ARCHITECTURE (ALL ROLES USE THIS SAME APP):
--------------------------------------------------------------------------------
This single app dynamically adapts based on the user's logged-in role:

- 1) Agency Manager / Admin (Group 6 / 1):
     * Full control: Creates sheets with initial lead data.
     * Sheet View: Clean, modern Card/Box UI (not an Excel spreadsheet grid).
     * Click lead card to open comprehensive details modal (Common + Executive + Accounts fields).
     * Assigns sheet to Field/Office Executives or directly to Accounts.
     * Manages staff & team members.

- 2) Field Executive (Group 4) & Office Executive / Backend Staff (Group 5):
     * Views only assigned sheets.
     * Sheet View: Excel Spreadsheet Table Grid.
     * Visible Columns: Common + Executive fields (Accounts fields strictly hidden).
     * Updates executive details, process type, and lead status.
     * Quick "Send to Accounts" action button once leads are processed.

- 3) Accounts Staff (Group 2):
     * Views shared sheets.
     * Sheet View: Excel Spreadsheet Table Grid.
     * Visible Columns: Common + Accounts fields (Executive fields strictly hidden).
     * Edits financial data: Profit, Company Payment, Bank / Collected, Agency Payment.

When viewed on Mobile: Touch-optimized bottom navigation & adaptive cards.
When viewed on Desktop/Tablet: Sleek sidebar, responsive multi-column grid, and wide data table.

================================================================================
