import Foundation

/// All localized strings for EN and DE
enum Strings {
    private static let translations: [String: [String: String]] = [
        // Navigation
        "timetable": ["en": "Timetable", "de": "Stundenplan"],
        "homework": ["en": "Homework", "de": "Hausaufgaben"],
        "study_hub": ["en": "Study Hub", "de": "Lernbereich"],
        "messages": ["en": "Messages", "de": "Nachrichten"],
        "substitution_plan": ["en": "Substitution Plan", "de": "Vertretungsplan"],
        "settings": ["en": "Settings", "de": "Einstellungen"],
        "textbooks": ["en": "Textbooks", "de": "Schulbücher"],
        "analytics": ["en": "Analytics", "de": "Statistiken"],
        
        // Common
        "cancel": ["en": "Cancel", "de": "Abbrechen"],
        "save": ["en": "Save", "de": "Speichern"],
        "create": ["en": "Create", "de": "Erstellen"],
        "delete": ["en": "Delete", "de": "Löschen"],
        "done": ["en": "Done", "de": "Fertig"],
        "retry": ["en": "Retry", "de": "Erneut versuchen"],
        "search": ["en": "Search", "de": "Suchen"],
        "sync_now": ["en": "Sync Now", "de": "Jetzt synchronisieren"],
        "loading": ["en": "Loading...", "de": "Laden..."],
        "error": ["en": "Error", "de": "Fehler"],
        
        // Folders
        "folders": ["en": "FOLDERS", "de": "ORDNER"],
        "select_folder": ["en": "Select a Folder", "de": "Ordner auswählen"],
        "new_folder": ["en": "New Folder", "de": "Neuer Ordner"],
        "edit_folder": ["en": "Edit Folder", "de": "Ordner bearbeiten"],
        "folder_name": ["en": "Folder Name", "de": "Ordnername"],
        
        // Notes
        "select_note": ["en": "Select a Note", "de": "Notiz auswählen"],
        "new_note": ["en": "New Note", "de": "Neue Notiz"],
        "no_notes": ["en": "No notes yet", "de": "Noch keine Notizen"],
        "generate_materials": ["en": "✨ Generate Study Materials", "de": "✨ Lernmaterialien erstellen"],
        "generating": ["en": "Generating Study Materials...", "de": "Lernmaterialien werden erstellt..."],
        "from_text": ["en": "From Text", "de": "Aus Text"],
        "from_pdf": ["en": "From PDF", "de": "Aus PDF"],
        "from_image": ["en": "From Image", "de": "Aus Bild"],
        "from_docx": ["en": "From DOCX", "de": "Aus DOCX"],
        "paste_content": ["en": "Paste or type your study content", "de": "Füge deinen Lerninhalt ein"],
        
        // Study Tools
        "notes": ["en": "Notes", "de": "Notizen"],
        "quiz": ["en": "Quiz", "de": "Quiz"],
        "flashcards": ["en": "Cards", "de": "Karten"],
        "chat": ["en": "Chat", "de": "Chat"],
        
        // Quiz
        "question_of": ["en": "Question %d of %d", "de": "Frage %d von %d"],
        "submit_answer": ["en": "Submit Answer", "de": "Antwort abgeben"],
        "next_question": ["en": "Next Question →", "de": "Nächste Frage →"],
        "see_results": ["en": "See Results 🎉", "de": "Ergebnisse 🎉"],
        "quiz_complete": ["en": "Quiz Complete!", "de": "Quiz abgeschlossen!"],
        "retake_quiz": ["en": "🔄 Retake Quiz", "de": "🔄 Quiz wiederholen"],
        "explanation": ["en": "Explanation", "de": "Erklärung"],
        
        // Flashcards
        "card_of": ["en": "Card %d of %d", "de": "Karte %d von %d"],
        "show_answer": ["en": "Show Answer", "de": "Antwort zeigen"],
        "deck_complete": ["en": "Deck Complete!", "de": "Stapel abgeschlossen!"],
        "review_unknown": ["en": "📝 Review Unknown", "de": "📝 Unbekannte wiederholen"],
        "full_reset": ["en": "🔄 Full Reset", "de": "🔄 Komplett zurücksetzen"],
        "all_caught_up": ["en": "All caught up!", "de": "Alles erledigt!"],
        "generate_cards": ["en": "Generate Cards", "de": "Karten erstellen"],
        "card_count": ["en": "Card Count", "de": "Kartenanzahl"],
        "special_instructions": ["en": "Special Instructions (Optional)", "de": "Besondere Anweisungen (Optional)"],
        
        // Chat
        "chat_with_notes": ["en": "Chat with your Notes", "de": "Chatte mit deinen Notizen"],
        "ask_about_notes": ["en": "Ask about your notes...", "de": "Frage zu deinen Notizen..."],
        
        // Timetable
        "subjects": ["en": "Subjects", "de": "Fächer"],
        "new_subject": ["en": "New Subject", "de": "Neues Fach"],
        "edit_subject": ["en": "Edit Subject", "de": "Fach bearbeiten"],
        "periods_per_day": ["en": "Periods per Day", "de": "Stunden pro Tag"],
        "assign_subject": ["en": "Assign Subject", "de": "Fach zuweisen"],
        "remove_subject": ["en": "Remove Subject", "de": "Fach entfernen"],
        
        // Homework
        "add_homework": ["en": "Add Homework", "de": "Hausaufgabe hinzufügen"],
        "no_homework": ["en": "No homework to do", "de": "Keine Hausaufgaben"],
        "hide_done": ["en": "Hide Done", "de": "Erledigte ausblenden"],
        "show_all": ["en": "Show All", "de": "Alle anzeigen"],
        "missing_homework": ["en": "Missing Homework", "de": "Fehlende Hausaufgaben"],
        
        // Messages
        "no_messages": ["en": "No Messages", "de": "Keine Nachrichten"],
        "sync_messages": ["en": "Sync with Logineo to fetch messages", "de": "Mit Logineo synchronisieren"],
        
        // Settings
        "ai_model": ["en": "AI Model", "de": "KI-Modell"],
        "api_key": ["en": "API Key", "de": "API-Schlüssel"],
        "logineo": ["en": "Logineo Credentials", "de": "Logineo-Zugangsdaten"],
        "language": ["en": "Language", "de": "Sprache"],
        "school_url": ["en": "School URL", "de": "Schul-URL"],
        "username": ["en": "Username", "de": "Benutzername"],
        "password": ["en": "Password", "de": "Passwort"],
        "test_connection": ["en": "Test Connection", "de": "Verbindung testen"],
        "about": ["en": "About", "de": "Über"],
        "danger_zone": ["en": "Danger Zone", "de": "Gefahrenzone"],
        "remove_api_key": ["en": "Remove API Key", "de": "API-Schlüssel entfernen"],
        
        // Textbook
        "upload_textbook": ["en": "Upload Textbook", "de": "Schulbuch hochladen"],
        "extract_page": ["en": "Extract Page", "de": "Seite extrahieren"],
        "solver_prompt": ["en": "Solver Prompt", "de": "Lösungs-Prompt"],
        "copy": ["en": "Copy", "de": "Kopieren"],
        "save_page": ["en": "Save Page", "de": "Seite speichern"],
    ]
    
    static func get(_ key: String, language: AppLanguage) -> String {
        translations[key]?[language.rawValue] ?? translations[key]?["en"] ?? key
    }
}
