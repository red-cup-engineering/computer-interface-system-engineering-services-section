// prove-commands — history, aliases, triggers, and the slash-vs-send parse.

import { ok, eq, done } from "./_harness.mjs";
import { History, expandAlias, matchTriggers, parseInput } from "../src/commands.mjs";

// history recall
{
  const h = new History();
  h.submit("look"); h.submit("north"); h.submit("kill rat");
  eq(h.recall(-1), "kill rat", "recall(-1) is the newest");
  eq(h.recall(-1), "north", "recall(-1) again steps older");
  eq(h.recall(-1), "look", "recall(-1) reaches the oldest");
  eq(h.recall(+1), "north", "recall(+1) steps newer");
  h.submit("flee");
  eq(h.recall(-1), "flee", "submit resets the cursor to the newest");
  // duplicate consecutive submits are coalesced
  h.submit("flee");
  eq(h.items.filter((x) => x === "flee").length, 1, "consecutive duplicate submits coalesce");
}

// alias expansion with $* and positionals
{
  const aliases = { k: "kill $*", gv: "give $1 to $2", n: "north" };
  eq(expandAlias(aliases, "k big rat"), "kill big rat", "$* expands to the rest");
  eq(expandAlias(aliases, "gv sword guard"), "give sword to guard", "$1/$2 expand positionally");
  eq(expandAlias(aliases, "n"), "north", "a no-arg alias expands");
  eq(expandAlias(aliases, "look here"), "look here", "a non-alias line passes through unchanged");
}

// triggers: substring and regexp
{
  const triggers = [
    { pattern: "You are hungry", send: "eat bread" },
    { pattern: /(\d+) gold coins/, send: "get coins" },
  ];
  eq(matchTriggers(triggers, "You are hungry.").length, 1, "a substring trigger fires");
  const fired = matchTriggers(triggers, "There are 42 gold coins here.");
  eq(fired.length, 1, "a regexp trigger fires");
  eq(fired[0].groups, ["42"], "the regexp groups are captured");
  eq(matchTriggers(triggers, "nothing matches").length, 0, "no trigger fires on a non-match");
}

// parseInput: slash-command vs send
{
  eq(parseInput("/connect host 4000"), { kind: "command", name: "connect", args: "host 4000" }, "/x parses as a command with args");
  eq(parseInput("/quit"), { kind: "command", name: "quit", args: "" }, "a no-arg slash command");
  eq(parseInput("say hello"), { kind: "send", text: "say hello" }, "plain text is a send");
  eq(parseInput(""), { kind: "send", text: "" }, "an empty line is still a send (bare Enter)");
}

done("prove-commands");
