database argument_ids {
  stringmap(int) /next
}

module Ids {
  function get(key) {
    match (?/argument_ids/next[key]) {
      | {none} -> 1
      | {some:id} -> id
    }
  }

  function next(key, exists) {
    res = get(key);
    /argument_ids/next[key] <- (res + 1);
    if (exists(res)) {
      next(key, exists)
    } else res
  }
}
