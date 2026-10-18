extends RefCounted
## Checks shared by the three presentation sources. A report is a plain
## dictionary {errors:[], warnings:[], coverage:{kind:{id:status}}}; builders
## append to it and never stop at the first problem.
const ASSETS := "res://assets/"
const SERVER_IDS := "res://authoring/server_ids.json"
const Root = preload("res://presentation/source/source_root.gd")

static func report() -> Dictionary:
    return {"errors": [], "warnings": [], "coverage": {}}

static func error(report: Dictionary, where: String, message: String) -> void:
    report.errors.append(where + ": " + message)

static func warn(report: Dictionary, where: String, message: String) -> void:
    report.warnings.append(where + ": " + message)

## Loads a root and every entry it lists. An entry file in the root's folder
## that the root does not list is an error, and so is a listed file that is
## missing or of the wrong section.
static func load_root(path: String, report: Dictionary) -> Dictionary:
    var root: Root = load(path) if FileAccess.file_exists(path) else null
    if root == null:
        error(report, path, "root missing")
        return {}
    var entries := {}
    var listed := {}
    for section in root.sections:
        entries[section] = {}
        for id in root.sections[section]:
            var file: String = root.sections[section][id]
            listed[file] = true
            var entry: Resource = load(file) if FileAccess.file_exists(file) else null
            if entry == null:error(report, path, section + "/" + id + " listed but " + file + " is missing");continue
            entries[section][id] = entry
    var folder := path.get_basename()
    for file in _files(folder):
        if file.ends_with(".tres") and not listed.has(file):error(report, path, file + " exists but no section lists it")
    return {"root": root, "entries": entries}

static func _files(folder: String) -> PackedStringArray:
    var out := PackedStringArray()
    var dir := DirAccess.open(folder)
    if dir == null:return out
    for sub in dir.get_directories():out.append_array(_files(folder.path_join(sub)))
    for file in dir.get_files():out.append(folder.path_join(file))
    return out

## Every asset path in a source is relative to res://assets/ and must exist inside the project.
static func asset(report: Dictionary, where: String, path: String) -> bool:
    if path.is_empty():return true
    if path.is_absolute_path() or path.begins_with("res://") or path.contains(".."):
        error(report, where, "asset path must be relative to res://assets/: " + path)
        return false
    if not FileAccess.file_exists(ASSETS + path):
        error(report, where, "asset missing: " + path)
        return false
    return true

static func server_ids() -> Dictionary:
    if not FileAccess.file_exists(SERVER_IDS):return {}
    return JSON.parse_string(FileAccess.get_file_as_string(SERVER_IDS))

## Records the presentation status of one server id (ready, partial, stand_in, missing, internal).
static func cover(report: Dictionary, kind: String, id: String, status: String) -> void:
    if not report.coverage.has(kind):report.coverage[kind] = {}
    report.coverage[kind][id] = status
