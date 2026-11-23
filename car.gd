extends Node2D

func _ready() -> void:
	#$AnimationPlayer.play("new_animation")
	var rp := Node.new()
	add_child(rp)
	var im := await SVSSceneExporter.export_image($Body, {}, rp, false)
	var sf := await SVSSceneExporter.export_sprite_frames(
		$Body, $AnimationPlayer, "new_animation", 60, rp, func(msg : String): print(msg), false
	)
	rp.queue_free()
	$TestSprite2D.texture = ImageTexture.create_from_image(im)

	var sprite_frames : SpriteFrames = $AnimatedSprite2D.sprite_frames
	sprite_frames.add_animation("test")
	sprite_frames.set_animation_speed("test", 60)
	for t in sf:
		sprite_frames.add_frame("test", ImageTexture.create_from_image(t))
	$AnimatedSprite2D.play("test")
