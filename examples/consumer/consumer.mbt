///|
/// A game-side adapter. No browser or engine-private state is needed.
pub fn accept_and_save(source : String) -> String raise @story.StoryError {
  @story.start(@story.compile(source)).advance().choose("accept").save()
}
