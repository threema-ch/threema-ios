# Known Issues

This section lists known issues with our protocols that are either unlikely to
occur or have a relatively low impact and are deemed acceptable for the time
being. Potential solutions may be suggested as well.

## Chat Server Protocol

### Groups: `group-leave` races with `group-setup`

**Scenario:**

1. _A_ is the creator of a group, _B_ and _C_ are members of it.
2. _B_ now leaves the group and sends a [`group-leave`](ref:e2e.group-leave) to
   all group members.
3. At the same time, _A_ announces a new member _D_ and sends a
   [`group-setup`](ref:e2e.group-setup) with `members` set to _B_, _C_ and _D_.
4. _A_ now handles the [`group-leave`](ref:e2e.group-leave) and removes _B_ from
   its local members list. The result of its internal local members list will be
   _A_, _C_, _D_.
5. Since there is no guaranteed order between group member messages:
   1. If _C_ received the [`group-leave`](ref:e2e.group-leave) first, it will
      remove _B_ from its local members list and then with the subsequent
      [`group-setup`](ref:e2e.group-setup) re-add _B_ and additionally add _D_.
      The result of its internal local members list will be _A_, _B_, _C_, _D_
      which is incorrect from _A_'s perspective.
   2. If _C_ received the [`group-setup`](ref:e2e.group-setup) first, it will
      add _D_ to its local members list and then with the subsequent
      [`group-leave`](ref:e2e.group-leave) remove _B_. The result of its
      internal local members list will be _A_, _C_, _D_.
6. Moreover, once _B_ handles the [`group-setup`](ref:e2e.group-setup), it will
   consider itself being re-added to the group. The result of its internal local
   members list will be _A_, _B_, _C_, _D_ which is incorrect from _A_'s
   perspective.

The result will be an inconsistent members list across the group members.

The issue listed in step 5.1. is unlikely to occur. But if it occurs, it will
resolve itself quickly. Once _C_ sends a group message to _B_, _B_ will respond
with [`group-leave`](ref:e2e.group-leave) again.

The issue listed in step 6. is also quite unlikely to occur. If it occurs and
_B_ sends a message to the group, group members will ignore those messages and
the group creator will respond with a [`group-setup`](ref:e2e.group-setup)
carrying an empty `members` list.

Another possibility is that the issues 5.1 and 6. happen in combination where
some consider _B_ part of the group, some do not and _B_ itself also considers
itself part of the group. Although this is a very confusing state, it should
resolve itself quickly with the above noted caveats.

In any case, the _Periodic Sync_ will eventually take care of it, so the effect
lasts at most 7 days.

**Solution:**

When the creator of the group receives a [`group-leave`](ref:e2e.group-leave),
it always sends a [`group-setup`](ref:e2e.group-setup) to all members after a
reasonable delay (to mitigate yet another race). Potential side effects would
have to be evaluated.
