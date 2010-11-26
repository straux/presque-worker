package presque::worker::Middleware::ClientID;

use Moose;
extend 'Net::HTTP::Spore::Middleware';

has worker_id => ( is => 'rw', isa => 'Str', predicate => 'has_worker_id' );

sub call {
    my ( $self, $req ) = @_;

    if ( $self->has_worker_id ) {
        $req->header( 'X-presque-workerid' => $self->worker_id );
    }
}

1;
