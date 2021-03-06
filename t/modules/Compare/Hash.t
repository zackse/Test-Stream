use Test::Stream -V1, Spec, Class => ['Test::Stream::Compare::Hash'], Compare => '*';

tests simple => sub {
    my $one = $CLASS->new();
    isa_ok($one, $CLASS, 'Test::Stream::Compare');

    is($one->name, '<HASH>', "name is <HASH>");
};

tests verify => sub {
    my $one = $CLASS->new();

    ok(!$one->verify(exists => 0),      "nothing to verify");
    ok(!$one->verify(exists => 1, got => undef), "undef is not a hashref");
    ok(!$one->verify(exists => 1, got => 1),     "1 is not a hashref");
    ok(!$one->verify(exists => 1, got => []),    "An arrayref is not a hashref");

    ok($one->verify(exists => 1, got => {}), "got a hashref");
};

tests init => sub {
    my $one = $CLASS->new();
    ok($one, "args are not required");
    is($one->items, {}, "got the items hash");
    is($one->order, [], "got order array");

    $one = $CLASS->new(inref => { a => 1, b => 2 });
    is($one->items, {a => 1, b => 2}, "got the items hash");
    is($one->order, ['a', 'b'], "generated order (ascii sort)");

    $one = $CLASS->new(items => { a => 1, b => 2 }, order => [ 'b', 'a' ]);
    is($one->items, {a => 1, b => 2}, "got the items hash");
    is($one->order, ['b', 'a'], "got specified order");

    $one = $CLASS->new(items => { a => 1, b => 2 });
    is($one->items, {a => 1, b => 2}, "got the items hash");
    is($one->order, ['a', 'b'], "generated order (ascii sort)");

    like(
        dies { $CLASS->new(inref => {a => 1}, items => {a => 1}) },
        qr/Cannot specify both 'inref' and 'items'/,
        "inref and items are exclusive"
    );

    like(
        dies { $CLASS->new(inref => {a => 1}, order => ['a']) },
        qr/Cannot specify both 'inref' and 'order'/,
        "inref and order are exclusive"
    );

    like(
        dies { $CLASS->new(items => { a => 1, b => 2, c => 3 }, order => ['a']) },
        qr/Keys are missing from the 'order' array: b, c/,
        "Missing fields in order"
    );
};

tests add_field => sub {
    my $one = $CLASS->new();

    $one->add_field(a => 1);
    $one->add_field(c => 3);
    $one->add_field(b => 2);

    like(
        dies { $one->add_field(undef, 'x') },
        qr/field name is required/,
        "Must specify a field name"
    );

    like(
        dies { $one->add_field(a => 1) },
        qr/field 'a' has already been specified/,
        "Cannot add field twice"
    );

    is($one->items, { a => 1, b => 2, c => 3 }, "added items");
    is($one->order, [ 'a', 'c', 'b' ], "order preserved");
};

tests deltas => sub {
    my $convert = Test::Stream::Plugin::Compare->can('strict_convert');

    my %params = (exists => 1, convert => $convert, seen => {});

    my $one = $CLASS->new(inref => {a => 1, b => 2, c => 3, x => DNE()});

    is(
        [$one->deltas(got => {a => 1, b => 2, c => 3}, %params)],
        [],
        "No deltas, perfect match"
    );

    is(
        [$one->deltas(got => {a => 1, b => 2, c => 3, e => 4, f => 5}, %params)],
        [],
        "No deltas, extra items are ok"
    );

    $one->set_ending(1);
    is(
        [$one->deltas(got => {a => 1, b => 2, c => 3, e => 4, f => 5}, %params)],
        [
            {
                dne      => 'check',
                verified => F(),
                id       => [HASH => 'e'],
                got      => 4,
                chk      => F(),
            },
            {
                dne      => 'check',
                verified => F(),
                id       => [HASH => 'f'],
                got      => 5,
                chk      => F(),
            },
        ],
        "Extra items are no longer ok, problem"
    );

    is(
        [$one->deltas(got => {a => 1}, %params)],
        [
            {
                children => [],
                dne      => 'got',
                verified => F(),
                id       => [HASH => 'b'],
                got      => F(),
                chk      => T(),
            },
            {
                children => [],
                dne      => 'got',
                verified => F(),
                id       => [HASH => 'c'],
                got      => F(),
                chk      => T(),
            },
        ],
        "Missing items"
    );

    is(
        [$one->deltas(got => {a => 1, b => 1, c => 1}, %params)],
        [
            {
                children => [],
                verified => F(),
                id       => [HASH => 'b'],
                got      => 1,
                chk      => T(),
            },
            {
                children => [],
                verified => F(),
                id       => [HASH => 'c'],
                got      => 1,
                chk      => T(),
            },
        ],
        "Items are wrong"
    );

    like(
        [$one->deltas(got => {a => 1, b => 2, c => 3, x => 'oops'}, %params)],
        [
            {
                verified => F(),
                id       => [HASH => 'x'],
                got      => 'oops',
                check    => DNE(),
            },
        ],
        "Items are wrong"
    );

};

done_testing;
