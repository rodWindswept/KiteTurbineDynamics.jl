# Room response: Note to Self silence mechanics (2026-10-12, aero-validator relay)

Rod restated the channel discipline tonight. The charter now says worker and
validator profiles do not reply on Note to Self, even when a message routes
into their session. This note records what the gateway does when a seat tries
to stay silent. It names the mechanism needed to make the rule achievable.

## What happens when a seat stays silent

Verified in the installed gateway code:

- The gateway rejects a bare silence marker on a live human turn. The markers
  are [SILENT], NO_REPLY, and the two shipped Chinese forms.
- The rejection replaces the marker with a visible warning: "⚠️ The model
  returned only a silence marker for a message that needed a reply. Try again
  or rephrase." (gateway/run_turn.py:1537-1543, gateway/response_filters.py:126-128)
- An empty reply also becomes a visible warning: "⚠️ Processing completed but
  no response was generated." See _normalize_empty_agent_response in
  gateway/run.py.
- Ordinary text always posts.

So no completed seat turn on Note to Self can be post-free today. A silent
seat produces a stub or a warning bubble instead. Tonight the seats that
received the message produced short stubs of 82 to 328 characters, or their
turns still run. None could vanish. The stubs state non-posting intent while
posting.

## Why silence fails

The gateway allows silence only on machinery turns, and when the adapter
marks a message reply_expected False. The Slack adapter sets that field for
unaddressed messages. The Signal adapter never sets it (gateway/platforms/signal.py,
the MessageEvent construction).

## What would make the rule work

1. Signal adapter sets reply_expected False, gated by profile config (an
   extra key or an env flag). A bare [SILENT] final then stays silent with
   zero output. This mirrors the Slack pattern, and seat rules would say:
   emit [SILENT]. The patch is small. Add a regression test that no empty
   payload reaches the send site.
2. Accept a one-line floor per message as the steady state, and word the
   rules that way.
3. Heavy option: intake drop per profile, so no turn runs. That loses
   channel awareness for the seat.

Recommendation: option 1. Until it lands, the floor is one minimal line per
message. That is what this seat does.

Relayed only. Nothing edited beyond this file. aero-validator
