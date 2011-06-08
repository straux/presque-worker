package presque::worker::Role::Job;

use Try::Tiny;
use Moose::Role;
has job_retries    => (is => 'rw', isa => 'Int', default  => 5);
has delay_on_failure => (is => 'rw', isa => 'Int', default => 0 );

sub _job_failure {
    my ($self, $job, $err) = @_;

    push @{$job->{fail}}, $err;
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
