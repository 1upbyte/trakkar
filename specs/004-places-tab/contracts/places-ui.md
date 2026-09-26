# Places UI Contract

- Places appears after People and before Settings in bottom navigation.
- List every saved place available to the signed-in account with its name and delete
  action.
- Adding starts with Auto or Manual choice. Auto selects mapped building data, previews
  a candidate boundary, and permits review/edit before naming. No usable building data
  offers Manual mode with an explanatory message.
- Manual mode lets users add/move polygon corners on the map. Invalid geometry cannot
  proceed to save.
- Both modes require a non-empty name and show the final boundary before save.
- A new place appears in list/map only after server save succeeds; failures preserve
  server-consistent state and explain the problem.
- Deletion confirmation names the target. Cancel does nothing; confirmed deletion
  removes the item after server success.
- Canceling creation discards its unsaved draft without creating a server record.
