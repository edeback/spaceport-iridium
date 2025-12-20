extends RichTextLabel

@export var time_event_messenger : TimeEventMessenger :
	set(value):
		if time_event_messenger != null:
			time_event_messenger.message_created.disconnect(_on_message_created)
	
		time_event_messenger = value
			
		if time_event_messenger != null:
			time_event_messenger.message_created.connect(_on_message_created)

## Whether to log signal events in the in game UI
@export var show_time_events = true

func _on_message_created(p_message : String):
	log_message(p_message)	

func log_message(p_message : String):
	if show_time_events:
		text += "\n" + p_message
