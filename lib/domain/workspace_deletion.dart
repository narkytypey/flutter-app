/// Whether [typed] matches [workspaceName] closely enough to arm the delete
/// button in spec `10c`'s "Type the name to confirm" field. Exact match
/// after trimming outer whitespace — no case-insensitivity, so a workspace
/// named "work" and one named "Work" are never confused by a careless typo.
bool confirmsDeletion(String typed, String workspaceName) =>
    typed.trim() == workspaceName;
