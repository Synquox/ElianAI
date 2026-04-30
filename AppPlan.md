# System Prompt: AI Student OS (Logineo Integration & Study Suite)

**Objective:** Build a high-performance iOS/iPadOS 26 application using SwiftUI and SwiftData that integrates with the Logineo LMS (Moodle-based), automates school organization, and uses Gemini API for intelligent study features.

---

## 1. Core Integration & Authentication

- **Logineo Scraper/API:** Implement a modular authentication system.
  - **Configurable URL:** Users must be able to input their specific school URL (Default: `169080.logineonrw-lms.de`).
  - **Session Management:** Store credentials securely in the Keychain. Implement a "Relogin" feature if the session expires.
- **Substitution Plan (Vertretungsplan):**
  - Allow the user to **manually select a specific course** where the substitution plan is located.
  - Inside that course, the AI must look for a file named "Vertretungsplan" (PDF).
  - **Auto-Update:** Monitor this file for changes. Whenever a new version is uploaded, it must replace the old one in the app.

## 2. Interactive Timetable & Homework Automation

- **Dynamic Timetable:**
  - Create a Mon-Fri grid. Users can define the number of periods per day.
  - Subjects can be renamed and **mapped to a specific Logineo Course ID**.
- **The 18:00 Logic (Background Sync):**
  - Every weekday at 18:00, the app performs a background sync.
  - **Scan Today:** Check all subjects that occurred today for new files or messages in the "Homework" section of Logineo.
  - **Re-check Yesterday:** Also check subjects from the previous day to see if teachers uploaded homework late.
  - **Persistence:** Homework entries stay in the list until manually "checked off."
- **Missing Homework Alerts:**
  - If no homework is found for a subject, the app displays a notification **one day before the next scheduled lesson** of that subject, warning the user to check manually.

## 3. Multi-Modal Study Hub

- **File Ingestion:** Support PDF, DOCX, PPT, TXT, and **Image files** (with OCR processing).
- **Language Support:** The entire app UI and AI responses must be switchable between **English and German**.
- **Study Workflow:**
  1.  **Summarization:** Generate structured notes/summaries immediately upon upload in the document's language.
  2.  **Chat:** A direct chat interface with Gemini to discuss the document.
  3.  **AI Quiz:** Auto-generate a 4-option multiple-choice quiz.
      - Features: "Hint", "Ask AI", and a "Why?" button for wrong answers.
  4.  **Flashcards:**
      - Option to set card count (10, 20, 30, 50).
      - Optional "Special Instructions" field for focus areas.
      - **UI:** A "Loading Screen" followed by a swipe-based study mode (Tap to flip, Swipe Right for "Known", Swipe Left for "Unknown").

## 4. Smart Textbook & Solver Logic

- **Textbook Mapping:** Users can upload a full textbook PDF and link it to a subject.
- **Deep Link Logic:** If a homework description mentions a page number (e.g., "S. 45"), the AI must:
  - Automatically extract and display that specific page from the linked textbook.
  - Provide a download button for that page.
  - **Solver Prompt:** Generate a pre-written prompt for a secondary AI (to be copied by the user) that explains the specific task on that page.

## 5. Message Center

- **Important Messages Tab:** Scrape Logineo chats/group messages daily at 18:00.
- **Smart Extraction:** If a chat message contains homework information, it must be automatically converted into a homework task in the UI.

## 6. Technical UI/UX Requirements (iOS 26)

- **Platform:** Optimized for iOS and iPadOS.
- **Design:** Modern, clean interface with haptic feedback and fluid transitions.
- **State Management:** Use `SwiftData` for local persistence of the timetable, homework status, and mapped courses.
- **Background Tasks:** Utilize `BackgroundTasks` framework for the 18:00 scraper to ensure data is ready when the user opens the app.

---

### Implementation Instructions for Cursor:

1.  **Phase 1:** Setup the SwiftUI navigation (Timetable, Homework, Study Hub, Settings).
2.  **Phase 2:** Develop the Logineo login and HTML parsing logic (use `SwiftSoup` or similar for scraping).
3.  **Phase 3:** Integrate Gemini API for the Summarization, Quiz, and Flashcard generation.
4.  **Phase 4:** Implement the background sync and notification logic.
5.  **Phase 5:** Build the PDF viewer and page extraction logic for the Textbook feature.
