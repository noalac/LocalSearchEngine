use Test::More 'no_plan';
use File::Spec;

# enter the src directory
chdir File::Spec->updir();
chdir "src";

my @subs = qw(LoadData StoreData RebuildData GetDataBase GetDataBaseKind);

# check for loading module
use_ok('Index', @subs); #1

# check for importing subs
can_ok(__PACKAGE__, @subs);  #2

# check for importing variable
ok( defined(%Index::bindb) ); #3





