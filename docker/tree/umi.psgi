use strict;
use warnings;

use UMI;

my $app = UMI->apply_default_middlewares(UMI->psgi_app);
$app;

