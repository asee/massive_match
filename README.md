# Massive Match

Massive Match makes it easy to match items to one another in complex ways. It currently implements Tuple Match, but may be expanded later to allow for other specialized problems. It relies on the LPSelect gem, which can be used for more generalized problems.

## Tuple Match

Matches groups of elements from an arbitrary number of sets. It can match across any number of sets, returning tuples, each containing one member from each composing set. For example, it can be used to match dogs with dog walkers:

Walkers: Alice, Bob, Carol
Dogs: Arnold, Bear, Clifford

One match would be: [Alice, Arnold]

You may specify rules for matches. Say, each dog must be walked by two different walkers.  Also, you could say that dogs can't be walked by humans whose names start with the same letter. In this case, only one outcome is possible.  The TupleMatch#match method specifies the arguments that can be handled.

### Example

```ruby
# set up the matcher
walkers = ['Alice', 'Bob', 'Carol', 'Chris']
dogs = ['Arnold', 'Bear', 'Clifford', 'Danger']
matcher = MassiveMatch::TupleMatch.new(
  :walkers => walkers,
  :dogs => dogs
)

# specify that we want each dog walked twice
matcher.set_matches_per_element(:dogs, 2)

# and that each walker can walk 1-3 dogs
matcher.set_matches_per_element(:walkers, 1..3)

# create a rule that disallows walkers from walking dogs whose names start
# with the same first letter as their walker
walker_name_markers = {}.tap do |wnm|
  walkers.each{|walker| wnm[walker] = walker[0..1]}
end

dog_name_markers = {}.tap do |wnm|
  dogs.each{|dog| wnm[dog] = dog[0..1]}
end

matcher.exclude_on_markers(
  :walkers => walker_name_markers,
  :dogs => dog_name_markers
)

# solve the equation
matches = matcher.match

# iterate over the results
matches.each do |walker,dog|
  # insert interesting code here
end
```


Note that you don't have to use strings for walkers and dogs, any object will
work just fine.
