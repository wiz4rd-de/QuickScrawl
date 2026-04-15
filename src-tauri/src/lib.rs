use std::fs;
use tauri::Manager;

#[tauri::command]
fn toggle_always_on_top(window: tauri::Window) -> Result<bool, String> {
    let current = window.is_always_on_top().map_err(|e| e.to_string())?;
    let new_state = !current;
    window.set_always_on_top(new_state).map_err(|e| e.to_string())?;
    Ok(new_state)
}

#[tauri::command]
fn save_note(app: tauri::AppHandle, content: String) -> Result<(), String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?;
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let file = dir.join("note.html");
    fs::write(&file, content).map_err(|e| e.to_string())
}

#[tauri::command]
fn load_note(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let dir = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?;
    let file = dir.join("note.html");
    if file.exists() {
        let content = fs::read_to_string(&file).map_err(|e| e.to_string())?;
        Ok(Some(content))
    } else {
        Ok(None)
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![save_note, load_note, toggle_always_on_top])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
