class_name ConditionPresentation
extends Resource
const BodyFilter = preload("res://presentation/resources/body_filter.gd")
const ActivityPose = preload("res://presentation/resources/activity_pose.gd")
const FeedbackText = preload("res://presentation/resources/feedback_text.gd")
const BodyOutline = preload("res://presentation/resources/body_outline.gd")
## Selected native presentation only. Gameplay, contacts and condition UUIDs are server data.
@export var behavior_id: String = ""
@export var body_filter: BodyFilter
@export var body_outline: BodyOutline
@export var activity_poses: Array[ActivityPose] = []
@export var application_feedback: FeedbackText
@export var removal_feedback: FeedbackText
