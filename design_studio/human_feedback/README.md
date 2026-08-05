# human_feedback

Raw human reactions to designs — the training signal for **stage 5** (preference
learning). Recorded in the **same shape the app uses**, so studio-collected taste
and in-app taste feed one learner.

- Append-only JSONL or one JSON per event, conforming to
  `feedback_record.schema.json`.
- Each event references a `recipeId` (so it ties back to an exact, reproducible
  design) and carries a signal (`like`/`dislike`/`chosen`/`purchased`/`dismissed`)
  plus optional notes.
- The learner folds these into `UserDesignPreferenceProfile.featureWeights`
  (schema in `design_engine/schemas`), respecting the clamps/learning-rate in
  `engine_config.json → preferenceLearning`.

Studio feedback typically uses a shared `userId` like `studio:<reviewer>` so it
biases the *global* priors, not a real user's profile.
