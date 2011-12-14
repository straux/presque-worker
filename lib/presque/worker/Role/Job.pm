package presque::worker::Role::Job;

use Try::Tiny;
use Moose::Role;
has job_retries          => (is => 'rw', isa => 'Int', default  => 5);
has max_error_stack_size => (is => 'rw', isa => 'Int', lazy => 1,
    default  => sub {
        my $self = shift;
        $self->job_retries == -1 ? 20 : $self->job_retries;
    },
);
has delay_on_failure     => (is => 'rw', isa => 'Int', default => 0 );

sub _job_failure {
    my ($self, $job, $err) = @_;

    $job ||= {};
    $job->{fail} ||= [];
    push @{$job->{fail}}, $err;
    # do not get an error stack too big
    if( @{$job->{fail}} > $self->max_error_stack_size ) {
        my @fail = @{$job->{fail}};
        $job->{fail} = [ @fail[ (-$self->max_error_stack_size)..-1] ];
    }

    my $retries = 1;

    if( $self->job_retries != -1 ) {
        $retries = ($job->{retries_left} || $self->job_retries) - 1;
        $job->{retries_left} = $retries;
    }

    try {
        my %args = ( queue_name => $self->queue_name, payload => $job );
        $args{delayed} = time + $self->delay_on_failure if $self->delay_on_failure;
        if( $retries > 0 ) {
            $self->retry_job( %args );
        } else {
            $self->retry_job( queue_name => $self->queue_name, lost => 1, payload => {} );
        }
    }
    catch {
        # XXX
        $err ||= '';
        $err .= " - error on job retry: $_";
    };
    $self->fail($job, $err ) if $self->_has_fail_method;
}

1;
