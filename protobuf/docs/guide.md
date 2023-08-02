# Protocol Specification Guide

**In this guide we will try to convey all necessary knowledge in order to read,
update and create new Threema protocol specifications. The primary goal is that
all developers are able to do this independently.**

We will also discuss [Implementation Suggestions](#implementation-suggestions),
[Tooling](#tooling), and the [Specification Flow](#specification-flow) for
working on protocol specifications and implementations.

🙏 Please, take the time to read it from the beginning to the end before you
start working on our protocols. Afterwards, your local _Head of Protocols_ will
happily assist you in case you have any questions or would like some further
guidance.

## Overview

A protocol specification usually consists of...

- an intro section roughly outlining its purpose,
- terminology and further miscellaneous definitions, e.g. key derivations,
- an overview of the protocol flows,
- some structs/messages, and
- the associated logic in form of _steps_.

The protocol's scope goes much beyond the network layer. Steps need to
describe...

- how struct/message fields are validated (when needed),
- how cryptography mechanisms are applied,
- how app state is modified by creating, sending or receiving a struct/message,
- if and what should be signalled to the user when a struct/message is being
  created, sent or received, and
- user interaction and consent requirement, especially in upgrade and error
  cases.

The protocol and the steps should not...

- for example, define an implementation's database layout, or
- describe UI designs, UI arrangements or overly precise UI flows.

## Disclaimer

Not everything will be described in this guide in absolute detail. **As a rule
of thumb, orient style, format and language of your work on the existing
protocol specifications.**

ℹ️ As of today, we still have a lot of incomplete documentation. An exemplary
candidate for a prime documentation to base your work on is the Group Calls
protocol.

## Target Audience

**This documentation is primarily written for and by Threema developers**. It
should not go into unnecessary detail to explain things for non-developers or
non-Threema employees. Abbreviations do not need to be written out if they are
defined somewhere within the protocol specifications, especially not if they are
part of a core protocol (e.g. the CSP). But try not to go overboard with them.

## Style & Format

The main format to document our protocols is Markdown.

One of our primary goals is to keep the specs readable in source because this is
what developers will most often have to work with. While the HTML-rendered specs
have their use, it is simply much easier to look at the source than having to
find the correct revision of the HTML-rendered specs matching the one currently
being referenced in a submodule. This means that no fancy inline HTML
shenanigans should be included. Even markdown links and references should be
minimised and we will consistently work on our tooling to make it as
non-disruptive to read in source as possible.

When making a flow graph, just use ASCII art and keep it simple. There are
several existing protocol specifications you can use as a template.

## Intro Section

In the intro section, we first of all present a rough outline on the purpose of
a specification. For example:

    # Chat Server Protocol

    The Chat Server Protocol is a custom transport encrypted frame-based
    protocol, originally designed to operate on top of TCP. [...]

## Terminology

When introducing terms, for example protocol roles, keys and their
abbreviations, etc., list them in their own _Terminology_ subsection.

    ## Terminology

    - `CK`: Client Key (permanent secret key associated to the Threema ID)
    - `ID`: The client's Threema ID
    - `Box(A, B)`: A NaCl box encrypted with key A and key B
    [...]

## General Information

The _General Information_ and other similar subsections (e.g. _Box_ and _Size
Limitations_) declare vital constants present throughout the specification, such
as the endianness, nonce format, sequence number format, etc. so they can be
assumed in other sections.

    ## General Information

    **Endianness**: All integers use little-endian encoding.
    [...]

## Key Derivations

When introducing key derivations, list those derivations in their own _Key
Derivation_ subsection.

    ## Key Derivation

    GCKH = BLAKE2b(key=GCK, salt='#', personal='3ma-call')
    [...]

## Protocol Flow

Following any general information subsections, each protocol flow should be
outlined in its own subsection, mentioning associated structs/messages and
roles.

Protocol flows may declare logic related to application state, user interaction
and scheduled/recurring events in form of [_steps_](#Steps). For lock-step
flows, we also define a visualisation of the flow.

### Flow Graphs

Describing flows with the help of ASCII art is very helpful in understanding the
overall mechanics of the protocol specification. It also visualises the
round-trip times.

    C ----- Hello ---> S
    C <---- Hello ---- S
    C ----- Auth ----> S
    C <---- Auth ----- S

This is easily done for lock-step (e.g. handshake) flows but often we have a
looping reactive (e.g. post-handshake) flow that is either too straightforward
or too complex to be described well with a flow graph. But there can be
exceptions in which case you are encouraged to describe the flow with ASCII art.

### Flow Logic

**It is vital to consider all of the following interactions with the protocol as
necessary parts of the specification.**

Protocol flows...

- can modify or be influenced by **application state**,
- can be influenced by or require **user interaction**,
- can be triggered by receiving or trigger sending **structs/messages**, and
- can be triggered by or trigger **scheduled/recurring events**.

To describe some logic of a protocol flow, we require the use of
[_steps_](#Steps). In the following section we will define what _steps_ are and
provide an example to all four kinds of interactions.

## Steps

_Steps_ are what make specifications easy to implement because they are close to
the implementation's code.

Steps define logic. For us, this usually means the reaction to creating, sending
or receiving structs/messages, as well as the reaction to user interaction or
scheduled (recurring) events. They are intentionally different to how IETF-style
RFCs are written.

It has shown in practice that thinking like a developer in the specification
process massively benefits both implementation and specification precision while
also keeping the implementation as simple as possible. This is because by
_thinking code_ during the specification process, it is much easier to factor in
states and their potential race conditions and therefore avoiding implementation
pain points.

Likewise, implementors will massively benefit from the steps because they can be
conveyed to code in small pieces easily and without having to worry about
missing an important bit somewhere else in the specification. This drastically
reduces mental load and, if the implementation follows the steps precisely, also
reduces the potential for implementation-based bugs.

The following is a definition of what steps are precisely and how they should be
written.

#### Steps are code

**One or more steps define a section of synchronous/non-concurrently executed
logic.**

**Steps may only be asynchronously/concurrently executed if obviously
recognisable as such (e.g. HTTP requests) or if explicitly marked concurrent.**

This is an essential differentiation because we're mitigating races in the steps
logic. Those races are only mitigated by an implementation when it conveys
synchronous/non-concurrent steps into synchronous/non-concurrent code.

#### Using variables and fields

Steps may declare variables.

    1. Let `nonce` be a random nonce [...]

Those variables may be referenced or modified in subsequent fields.

    2. If `nonce` is empty [...]
    3. Set `nonce` to [...]

Steps associated to a message may directly reference fields with backticks.

    4. If the `sender` is unknown, discard the message [...]

#### Defining algorithms

Steps may define algorithms but should be concise when doing so.

👍 (Concise but simple)

    1. For each member of `members`, create a contact with acquaintance level
       _group_ if not already present in the contact list.

👎 (Overly verbose)

    1. For each member of `members`:
       1. Look up an associated contact for the identity of the member.
       2. If the contact could be found, abort these sub-steps.
       3. Create a new contact with the identity of member.
       4. Set the acquaintance level of the newly created contact to _group_.

#### Declaring and modifying state

State often does not need to be explicitly defined somewhere when the initial
state is obvious (e.g. the _left_ mark of a group). But if it needs to be
defined, it should be in the corresponding protocol flow subsection.

Steps may alter state declared in other sections by using the _mark_ keyword.

    1. If the action of the user triggering these steps was to disband or
       delete the group [...], mark the group as _left_ [...]

#### Conditionals and early aborts

Steps should make **heavy use of early aborts** to rule out error conditions and
edge cases as early as possible. This reduces mental load the further you
progress the steps and allows you to slowly prepare results in a step-by-step
fashion.

👍 (Early conditionals, early aborts)

    1. If the `Authorization` header is missing [...] abort these steps.
    2. If the provided data is invalid [...] abort these steps.
    3. If `call_id` does not equal the Call ID [...] abort these steps.
    4. If the `protocol_version` is unsupported by the SFU [...] abort these steps.
    5. Respond with status code `200` [...]

👎 (Unnecessary nesting)

    1. If the `Authorization` header is not missing:
       1. If the provided data is not invalid [...]:
          1. If `call_id` does equal the Call ID [...]:
             1. If the `protocol_version` is supported by the SFU [...]:
                1. Respond with status code `200` [...]

Complex or convoluted sentences with many conditionals are to be split up into
several sub-steps or reworked completely. Steps are to avoid surprising
_unless_-like conditionals at the end of the sentence.

👎 (Too many conditionals in a single step)

    1. If the `Authorization` header is missing [...], or the provided data is
       invalid [...], or the `call_id` does not equal the Call ID, or the
       `protocol_version` is unsupported by the SFU [...] abort these steps.
    2. Respond with status code `200` [...]

👎 (Surprising conditionals at the end of a step)

    1. Respond with status code `200` [...] unless the `Authorization` header
       is missing.

#### Jumping

It is allowed to jump and restart steps from the beginning or with a _label_ in
front of sub-steps. But this should be used with caution.

⚠️ (Restarting from the beginning of the steps)

    1. [...]
    2. [...]
    3. If [...], re-run these steps from the beginning.

⚠️ (Restarting from a label before sub-steps)

    1. For each `call` of `calls`, run the following steps (labelled _peek-call_)
       concurrently and wait for them to return:
       1. If [...] abort the _peek-call_ sub-steps.
       2. Restart the _peek-call_ sub-steps for this `call`.

👎 (Executing arbitrary steps and jumping back)

    1. [...]
    2. [...]
    3. If [...], re-run step 2 then continue here.

#### Looping

Steps may define a series of sub-steps for a loop.

    1. For each contact of the group:
       1. If the contact's Threema ID is [...], abort these steps.
       2. [...]
       3. Send a [...] message to the contact [...]

#### Footnotes and explainers

Use footnotes to explain the implication of a step that isn't obvious.

    1. Begin a transaction with transaction requirement `EXCLUSIVE` [...]. Retry
       indefinitely.¹
    2. [...]

    ¹: The only way out of this loop is if the server disconnects the client.
    Races are mitigated because other devices would also request an exclusive
    transaction [...]

Footnotes must be explained underneath the steps. There are other cases where
footnotes make a lot of sense, e.g. to clarify a step order that may look
confusing at first but has been carefully crafted that way to prevent race
conditions. **The next person working on the specification needs to know that to
not mess up your well-crafted logic!**

ℹ️ The concept of footnotes has been added recently, so we're not making good
use of it yet.

When steps aren't sufficient or may leave the reader confused, it is advisable
to add a brief prefacing section before the steps or an explainer paragraph
below the steps.

    1. [...]
    2. Return `chosen-call`.

    Note: The above steps have been carefully crafted to gracefully handle cases
    where the SFU of one call cannot be reached for a short period of time.

#### Common steps

When steps are needed in several places, define the common steps as part of a
protocol flow subsection and give them a name.

    The following steps are defined as the _Group Call Refresh Steps_ [...]:

    1. [...]

Common steps can be invoked by using the _run_ keyword.

    1. Run the _Group Call Refresh Steps_ and let `chosen-call` be the result.
    2. [...]

⚠️ Only do this for meaningful steps. Repeating yourself is often much more
readable than chopping logic into many common steps.

#### Other flow logic steps

Some steps are not needed to be referenced, nor can they be associated to a
specific struct/message. In such a case they should be part of a protocol flow
subsection and be named appropriately.

    #### Recurring Gateway Contact Profile Picture Refresh

    For contacts with a Threema Gateway ID (starting with a `*`), the profile
    picture needs to be fetched recurringly:

    1. Fetch the profile picture for the ID from `avatar.threema.ch`.
    2. If no profile picture could be found, schedule the next refresh in 24h
       and abort these steps.
    [...]

#### Think code

If you have no idea how to convey steps to code, rewrite them until you do.

### Implementation Suggestions

The following subsections should be kept in mind when implementing a protocol
specification.

Note: The section on how to prevent races is more an urge than a suggestion!

#### Preventing races

Because steps are usually non-concurrent and synchronous, and considering that
protocol code is rarely performance critical, it is highly advisable to
implement a specification by using a single thread running synchronous code.
This mitigates races which are painful to debug and have the tendency to only
blow up under certain conditions. Unfortunately, these conditions are rarely
encountered during development because we're bubble-wrapped in an environment
with predictable low latency and no packet loss, unlike our customers. So, spare
yourself the pain, don't do premature optimisation and just use a single thread.

Asynchronous sections can still lead to races if you're not careful. It is
advisable to add barriers/locks to guard against races in these situations. This
is also the reason why asynchronously or even parallelly executed code should
generally be avoided and that's no exception for our protocol specifications.

In addition, protocols may need to interact with one another. The following
protocol families exist and may be run in parallel, guarded by the family's
mutex in case an interaction with another protocolfamily is necessary:

- CSP (CSP E2E, MDM Parameter, HTTP APIs), Group Call, Threema Safe,
  Multi-Device (D2X, Rendezvous, Device Join, History Exchange) and everything
  not explicitly named in a separate scope are **one scope**.
- 1:1 Call Signalling
- Group Call Signalling
- Group Call Media Encryption

#### Tracking the specification steps

It can make sense to add comments referencing the step numbers. While this can
become tedious when the steps are updated, it may be even more tedious to find
all associated code sections when a step is being changed without the code
having comments referencing steps.

#### Specification compliance

Steps do not need to be followed precisely as long as the result is the same.
But it is recommended to follow them as close as possible to avoid confusion
when a step changes and help readers familiar with the spec but not the
implementation.

## Structs/Messages

Structs and messages are the primary part of our protocol specifications,
defining what is being exchanged between parties.

Every struct/message should have proactive and reactive steps associated to its
documentation. These steps should be preluded by writing
`When creating|sending|receiving this message:`, directly followed by the
enumerated steps.

In the following subsections, we will go through the three primary kinds of
formats we're using in our protocols and explain when they should be used and
what caveats they present.

### Structbuf

The CSP and some other protocols follow a traditional struct-based format, i.e.
a packed sequence of bytes where fields are interpreted by their offset. The
_structbuf_ format describes how that struct is formed.

Note that there should be a good reason to use structs over Protobuf because of
the inflexibilities of the format. Extensions of the CSP (e.g. CleVER Extension
fields), or anything else the chat server needs to parse, should use structs to
keep the chat server simple. New protocols or E2EE messages should not use
structs!

#### Format

Structbuf structs are defined in YAML files and can be used to generate code.

A structbuf YAML file consists of an index and further namespaces.

    namespaces:
      index: *index
      payload: *payload
      [...]

Each namespace contains an arbitrary amount of structs. A struct has a `fields`
property declaring an ordered list of fields, each of which has a `name` and a
`type` property.

    payload: &payload
      frame:
        fields:
          - name: length
            type: u16-le
          - name: box
            type: b{length}
      [...]

Nesting is not possible in structbuf. The inner struct should simply be
documented.

    extension:
      - _doc: |-
          Extension payload. Needs to be parsed according to the `type` field.
        name: payload
        type: b{length}

The following structbuf types are relevant for our use cases:

- `u8`, `u16-le`, `u32-le` and `u64-le` are little-endian encoded, unsigned
  integers.
- `bX` where `X` is an unsigned integer declares a fixed-size byte sequence.
- `b{length-reference}` declares a dynamically sized byte sequence where the
  amount of bytes depends on the field `length-reference` (which must be an
  unsigned integer).
- `b*` can only be applied to the end of the `fields` list and yields any
  remaining bytes.

### JSON

On our road to iron out the inflexibilities of structs, we went through an
intermediate phase where we embedded JSON into many CSP E2EE messages and HTTP
APIs.

JSON however has its own set of issues. Let's just name three which are relevant
to us and call it a day: Lack of a _bytes_ type, space inefficiency and having
to persist field names. Hence, JSON should be avoided for all future protocols,
network-exposed APIs and E2EE messages.

Currently, we're describing JSON payloads as part of a struct's field in the
following way.

    fields:
      - _doc: |-
          UTF-8, JSON-encoded object with the following fields:

          - Rendering type (`'j'`):
            - `0`: Render as a file.
            - `1`: Render as media (e.g. an image, audio or video).
            [...]
          - Encryption key (`'k'`): Random symmetric key used to encrypt the
            blobs (file and thumbnail data) in lowercase hex string.
          [...]

        name: file
        type: b*

ℹ️ We're considering to describe JSON payloads in separate JSON schema files as
started for the Threema Safe Backup (`safe-backup.json`).

### Protobuf

On our road to iron out the deficiencies of structs and JSON, we found a sweet
spot in _Protocol Buffers_, or _Protobuf_ in short. When we mention _Protobuf_,
we always mean version 3 with support for _explicit field presence_.

You can find a detailed documentation about Protobuf 3 [here][protobuf-docs]. We
agree with most but not all best practices mentioned in that documentation.
Specifically:

- The `0` value of an enum is allowed to be semantically meaningful. It should
  however ideally be a catch-all. Good examples are `NONE` and `ALL`.
- Do not use Google's Well-Known or Common types such as
  `google.protobuf.Timestamp` as we try to keep things pure. If we need such a
  type, it should be declared in `common.proto`.
- Ignore the advice on using `text` instead of integer IDs. Don't do that.

[protobuf-docs]: https://protobuf.dev/programming-guides/proto3/

Considering that you will mostly work with Protobuf when creating new E2EE
messages or protocols, and that there are a bunch of conventions we follow, we
will briefly go through how a typical message looks like and then a few **rules
of thumb**.

#### A typical message

The most important part of Protobuf is a `message` declaration containing an
arbitrary amount of fields. Fields are typed and are assigned a tag identifying
the field.

    message Blob {
      bytes id = 1;
      bytes nonce = 2;
    }

The most relevant scalar value types for our use cases are:

- `uint32` and `uint64` integers having a smaller byte representation if the
  integers are small, ideal for counted integers,
- `fixed32` and `fixed64` integers having a constant size but more efficiently
  encodable/decodable byte representation, ideal for random integers,
- `bytes` which is a sequence of bytes,
- `text` which is just UTF-8 encoded bytes,

There is a limited selection of integer types. Apply common sense to valid field
values. For example, a port number will most likely be declared as `uint32` but
in reality may not exceed an unsigned 16-bit integer.

`enum`s are superior over integers for... well... enumerations. Messages can
also be nested which makes them a powerful tool.

    message Image {
      // Enums are neat!
      enum Type {
        JPEG = 0;
        PNG = 1;
        WEBP = 2;
      }
      Type type = 1;

      // Nested message referencing our Blob declared further above
      Blob blob = 2;
    }

But one of the coolest features is `oneof`, allowing the generated code to only
provide one of the declared fields within its scope.

    message DeltaImage {
      oneof image {
        // The image is empty or was explicitly removed
        Unit removed = 1;
        // The new updated image
        Image updated = 2;
      }
    }

Using `repeated` allows for an ordered list of field values.

    repeated uint32 participant_ids = 1;

And using `map` allows to create an ordered map of key/value types (under the
hood, this is just a `repeated` message with _key_ and _value_).

    map<uint32, Participant> participants = 1;

#### Required by default

If a field is not explicitly declared as optional in the field's documentation,
assume that it is required.

    message Blob {
      // Setting this field is mandatory.
      bytes id = 1;
      // This one is mandatory, too!
      bytes nonce = 2;
    }

Now you may ask: Shouldn't the API require me to provide all non-optional field
values? And the answer is: We think it should be that way but it highly depends
on the code that is generated by your currently used code generator. This is
because all field types but `message` have a default value, even if they are not
assigned any value. [A full list of default values if not provided is in the
Protobuf docs][protobuf-docs-default].

[protobuf-docs-default]: https://protobuf.dev/programming-guides/proto3/#default

#### Optional by exception

In case you need a field to have a semantic difference between _empty_ and _not
present_ (e.g. providing _delta updates_ like we do in D2D sync), use the
`optional` keyword to make presence explicit.

If you can't follow, don't worry. Take a look at the following message and the
generated (TypeScript-like) interface:

    message PastIncomingMessage {
      [...]
      uint64 received_at = 2;
      optional uint64 read_at = 3;
      [...]
    }

    interface PastIncomingMessage {
      received_at: u64;
      read_at: u64 | undefined;
    }

That should be straightforward to understand. Unfortunately, the effects are not
that trivial if we consider that applications exchanging Protobuf messages can
have different versions of the respective messages:

Keep in mind how scalar types usually have a default value in Protobuf. If the
sender uses an older version of message that does not have the `received_at`
field in the message, the receiver would always pick up `received_at` as `0`
even if it was not present in the transmitted bytes.

However, if the sender does not have the `read_at` field in the message (which
is marked `optional`), the receiver would not translate it into the default
value but instead indicate that no field value is present for `read_at` (i.e.
that it is undefined).

Keep this in mind when designing fields.

#### Boolean is your enemy

There are dozens of articles out there on why booleans suck. For starters, they
are not very descriptive when passing them around and therefore often lead to
inadvertent inversion. More importantly for a protocol, they only allow for two
states and hence are not extensible.

👎 (Not descriptive, not extensible)

    bool is_work_contact = 1;

👍 (Represented as an `enum`)

    enum IdentityType {
      CONSUMER = 0;
      WORK = 1;
    }

👍 (Extended to a tri-state)

    enum IdentityType {
      CONSUMER = 0;
      WORK = 1;
      BOT = 2;
    }

#### Namespaces

Unlike structbuf, Protobuf does not have a way to declare namespaces. However,
this can be easily emulated by nesting `message`s inside a `message` that has no
fields.

    message Admin {
      message PromoteToAdmin { [...] }
      message ForceCaptureStateOff { [...] }
      [...]
    }

When you have a protocol that requires different roles, you should use this to
your advantage to separate the roles.

👎 (Roles are mixed)

    message SfuHello { [...] }
    message ParticipantHello { [...] }

👍 (Roles are separated)

    message SfuToParticipant {
      message Hello { [...] }
    }

    message ParticipantToSfu {
      message Hello { [...] }
    }

The same should be applied to split flows, e.g. splitting the handshake and
post-handshake phase.

Languages with clever type systems allow a clever developer to leverage this in
the types and only accept sending messages with / receiving messages from the
correct role.

### Naming

Naming things is hard. As mentioned in the disclaimer, orient on the existing
style. But here's a brief overview touching the most important things to keep
the protocols consistent:

- Structbuf structs and fields use `dash-case`.
- Protobuf messages use `PascalCase`, fields use `snake_case`.
- When naming, either use a proper word (e.g. `group`) or an abbreviation (e.g.
  `pck` referring to the Participant Call Key in the Group Calls protocol). But
  generally don't shorten words (e.g. `grp` for `group` or `msg` for `message`).

## Splitting

Sometimes it is necessary to have both Structbuf and Protobuf files for a new
protocol. In that case, take the one that is more significant and add the intro
section there. See the Group Calls protocol for an example.

If it is an umbrella protocol containing many subprotocols, create a separate
`md` file and add the intro section there. See the Multi-Device protocol suite
for an example.

## Readme & TOC

Last but not least, add any new specification to the `README.md` and `.toc.yml`
files.

## Tooling

Here, we'll provide a few notes on what kinds of tools should be used for
working on the protocol specifications and for generating code.

### Editor

We recommend to use VSCode with the
[recommended extensions](../.vscode/extensions.json).

- Prettier will assist you in reformatting Markdown, JSON and YAML files. Run
  `npm install` in the repository directory to use Prettier.
- For any kind of documentation, the Rewrap extension is a life saver to
  automatically rewrap paragraphs. The default keyboard shortcut is Alt+Q.
- The Protobuf extension adds syntax validation for Protobuf files.

### Code Generation

When you have the opportunity to choose a code generator for Protobuf, make sure
you're choosing one that has achieved some widespread use and is actively
maintained. Within those that fulfill this requirement, choose the one that
generates idiomatic code for your language (even if it isn't the most popular
one - the good ones rarely are).

⚠️ The default Protobuf code generator from Google generates atrocious code.

## Specification Flow

Okay, this overview was hopefully useful to you. But there's probably one thing
nagging you: Where does one even start when writing a protocol specification?
And when is it done?

Let's go through the process, step by step:

1. Think about the necessary protocol flows and start by drafting
   structs/messages including fields without any documentation.
2. Discuss the idea with your colleagues until you have a clear vision of how
   the protocol should function. From this point onward, involve and sync with
   your local _Head of Protocols_. 😊
3. Once you have a clear vision you want to commit yourself to, start adding
   struct/message and associated field documentation and steps to the
   structs/messages. When you encounter logic you cannot express as part of a
   message, define these steps as part of a protocol flow subsection. Add
   terminology, key derivations (and other crypto-related properties) and
   protocol flows incrementally when you encounter them. Ensure you're covering
   the three other kinds of protocol interactions: User interaction, application
   state modification and scheduled/recurring events.
4. This is the point in time where proof of concept implementations may be
   initiated. If you're writing the specification **and** the implementation, it
   can make sense to begin with it much earlier but keep in mind that steps
   _are_ code and everything will have to be reviewed and potentially refactored
   once the steps are added! This becomes even more tedious when your colleagues
   start joining you in writing the implementations.
5. At this point, your spec is probably almost completely thought out, so add
   any missing steps, abstract, ASCII flows, etc.
6. Go through the requirements outlined by this guide and ensure your protocol
   specification follows them. Then, reach out for a final review and get it
   merged. 🎉

Note that this isn't any different for updating existing specifications, just a
lot more compressed.

⚠️ It can easily happen to get lost in implementation and forget to reach steps
5 and 6 outlined above. We have been there and done that too many times.
Everyone involved in the implementation process should remind one another to
prevent the specification process from falling behind or stalling completely!
