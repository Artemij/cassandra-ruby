module CassandraRuby
  module Thrift
    # The ConsistencyLevel is an enum that controls both read and write behavior
    # based on ReplicationFactor in your storage-conf.xml. The different
    # consistency levels have different meanings, depending on if you're doing
    # a write or read operation. Note that if W + R > ReplicationFactor, where
    # W is the number of nodes to block for on write, and R the number to block
    # for on reads, you will have strongly consistent behavior; that is, readers
    # will always see the most recent write. Of these, the most interesting is
    # to do QUORUM reads and writes, which gives you consistency while still
    # allowing availability in the face of node failures up to half of
    # ReplicationFactor. Of course if latency is more important than
    # consistency then you can use lower values for either or both.
    #
    # Write:
    #   ZERO    Ensure nothing. A write happens asynchronously in background
    #   ANY     Ensure that the write has been written once somewhere, including
    #           possibly being hinted in a non-target node.
    #   ONE     Ensure that the write has been written to at least 1 node's
    #           commit log and memory table before responding to the client.
    #   QUORUM  Ensure that the write has been written to
    #           ReplicationFactor / 2 + 1 nodes before responding to the client.
    #   ALL     Ensure that the write is written to ReplicationFactor nodes
    #           before responding to the client.
    #
    # Read:
    #   ZERO    Not supported, because it doesn't make sense.
    #   ANY     Not supported. You probably want ONE instead.
    #   ONE     Will return the record returned by the first node to respond.
    #           A consistency check is always done in a background thread to fix
    #           any consistency issues when ConsistencyLevel.ONE is used. This
    #           means subsequent calls will have correct data even if the
    #           initial read gets an older value. (This is called 'read repair').
    #   QUORUM  Will query all storage nodes and return the record with the most
    #           recent timestamp once it has at least a majority of replicas
    #           reported. Again, the remaining replicas will be checked in the
    #           background.
    #   ALL     Not yet supported, but we plan to eventually.
    module ConsistencyLevel
      ZERO = 0
      ONE = 1
      QUORUM = 2
      DCQUORUM = 3
      DCQUORUMSYNC = 4
      ALL = 5
      ANY = 6

      VALUE_MAP = {
        0 => 'ZERO',
        1 => 'ONE',
        2 => 'QUORUM',
        3 => 'DCQUORUM',
        4 => 'DCQUORUMSYNC',
        5 => 'ALL',
        6 => 'ANY'
      }

      VALID_VALUES = Set.new([
          ZERO, ONE, QUORUM, DCQUORUM, DCQUORUMSYNC, ALL, ANY
        ]).freeze
    end

    # Basic unit of data within a ColumnFamily.
    # @param name. A column name can act both as structure (a label) or as data
    #        (like value). Regardless, the name of the column is used as a key
    #        to its value.
    # @param value. Some data
    # @param timestamp. Used to record when data was sent to be written.
    class Column
      include ::Thrift::Struct
      NAME = 1
      VALUE = 2
      TIMESTAMP = 3

      ::Thrift::Struct.field_accessor self, :name, :value, :timestamp

      FIELDS = {
        NAME => {:type => ::Thrift::Types::STRING, :name => 'name'},
        VALUE => {:type => ::Thrift::Types::STRING, :name => 'value'},
        TIMESTAMP => {:type => ::Thrift::Types::I64, :name => 'timestamp'}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field name is unset!') unless @name
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field value is unset!') unless @value
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field timestamp is unset!') unless @timestamp
      end
    end

    # A named list of columns.
    # @param name. see Column.name.
    # @param columns. A collection of standard Columns. The columns within
    #     a super column are defined in an adhoc manner.
    #     Columns within a super column do not have to have matching structures
    #     (similarly named child columns).
    class SuperColumn
      include ::Thrift::Struct
      NAME = 1
      COLUMNS = 2

      ::Thrift::Struct.field_accessor self, :name, :columns

      FIELDS = {
        NAME => {:type => ::Thrift::Types::STRING, :name => 'name'},
        COLUMNS => {:type => ::Thrift::Types::LIST, :name => 'columns', :element => {:type => ::Thrift::Types::STRUCT, :class => Column}}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field name is unset!') unless @name
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field columns is unset!') unless @columns
      end
    end

    # Methods for fetching rows/records from Cassandra will return either a single instance of ColumnOrSuperColumn or a list
    # of ColumnOrSuperColumns (get_slice()). If you're looking up a SuperColumn (or list of SuperColumns) then the resulting
    # instances of ColumnOrSuperColumn will have the requested SuperColumn in the attribute super_column. For queries resulting
    # in Columns, those values will be in the attribute column. This change was made between 0.3 and 0.4 to standardize on
    # single query methods that may return either a SuperColumn or Column.
    #
    # @param column. The Column returned by get() or get_slice().
    # @param super_column. The SuperColumn returned by get() or get_slice().
    class ColumnOrSuperColumn
      include ::Thrift::Struct
      COLUMN = 1
      SUPER_COLUMN = 2

      ::Thrift::Struct.field_accessor self, :column, :super_column
      FIELDS = {
        COLUMN => {:type => ::Thrift::Types::STRUCT, :name => 'column', :class => Column, :optional => true},
        SUPER_COLUMN => {:type => ::Thrift::Types::STRUCT, :name => 'super_column', :class => SuperColumn, :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
      end

    end

    # A specific column was requested that does not exist.
    class NotFoundException < ::Thrift::Exception
      include ::Thrift::Struct

      FIELDS = {

      }

      def struct_fields; FIELDS; end

      def validate
      end

    end

    # Invalid request could mean keyspace or column family does not exist, required parameters are missing, or a parameter is malformed.
    # why contains an associated error message.
    class InvalidRequestException < ::Thrift::Exception
      include ::Thrift::Struct
      def initialize(message=nil)
        super()
        self.why = message
      end

      def message; why end

      WHY = 1

      ::Thrift::Struct.field_accessor self, :why
      FIELDS = {
        WHY => {:type => ::Thrift::Types::STRING, :name => 'why'}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field why is unset!') unless @why
      end

    end

    # Not all the replicas required could be created and/or read.
    class UnavailableException < ::Thrift::Exception
      include ::Thrift::Struct

      FIELDS = {

      }

      def struct_fields; FIELDS; end

      def validate
      end

    end

    # RPC timeout was exceeded.  either a node failed mid-operation, or load was too high, or the requested op was too large.
    class TimedOutException < ::Thrift::Exception
      include ::Thrift::Struct

      FIELDS = {

      }

      def struct_fields; FIELDS; end

      def validate
      end

    end

    # invalid authentication request (user does not exist or credentials invalid)
    class AuthenticationException < ::Thrift::Exception
      include ::Thrift::Struct
      def initialize(message=nil)
        super()
        self.why = message
      end

      def message; why end

      WHY = 1

      ::Thrift::Struct.field_accessor self, :why
      FIELDS = {
        WHY => {:type => ::Thrift::Types::STRING, :name => 'why'}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field why is unset!') unless @why
      end

    end

    # invalid authorization request (user does not have access to keyspace)
    class AuthorizationException < ::Thrift::Exception
      include ::Thrift::Struct
      def initialize(message=nil)
        super()
        self.why = message
      end

      def message; why end

      WHY = 1

      ::Thrift::Struct.field_accessor self, :why
      FIELDS = {
        WHY => {:type => ::Thrift::Types::STRING, :name => 'why'}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field why is unset!') unless @why
      end

    end

    # ColumnParent is used when selecting groups of columns from the same ColumnFamily. In directory structure terms, imagine
    # ColumnParent as ColumnPath + '/../'.
    #
    # See also <a href="cassandra.html#Struct_ColumnPath">ColumnPath</a>
    class ColumnParent
      include ::Thrift::Struct
      COLUMN_FAMILY = 3
      SUPER_COLUMN = 4

      ::Thrift::Struct.field_accessor self, :column_family, :super_column
      FIELDS = {
        COLUMN_FAMILY => {:type => ::Thrift::Types::STRING, :name => 'column_family'},
        SUPER_COLUMN => {:type => ::Thrift::Types::STRING, :name => 'super_column', :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field column_family is unset!') unless @column_family
      end

    end

    # The ColumnPath is the path to a single column in Cassandra. It might make sense to think of ColumnPath and
    # ColumnParent in terms of a directory structure.
    #
    # ColumnPath is used to looking up a single column.
    #
    # @param column_family. The name of the CF of the column being looked up.
    # @param super_column. The super column name.
    # @param column. The column name.
    class ColumnPath
      include ::Thrift::Struct
      COLUMN_FAMILY = 3
      SUPER_COLUMN = 4
      COLUMN = 5

      ::Thrift::Struct.field_accessor self, :column_family, :super_column, :column
      FIELDS = {
        COLUMN_FAMILY => {:type => ::Thrift::Types::STRING, :name => 'column_family'},
        SUPER_COLUMN => {:type => ::Thrift::Types::STRING, :name => 'super_column', :optional => true},
        COLUMN => {:type => ::Thrift::Types::STRING, :name => 'column', :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field column_family is unset!') unless @column_family
      end

    end

    # A slice range is a structure that stores basic range, ordering and limit information for a query that will return
    # multiple columns. It could be thought of as Cassandra's version of LIMIT and ORDER BY
    #
    # @param start. The column name to start the slice with. This attribute is not required, though there is no default value,
    #               and can be safely set to '', i.e., an empty byte array, to start with the first column name. Otherwise, it
    #               must a valid value under the rules of the Comparator defined for the given ColumnFamily.
    # @param finish. The column name to stop the slice at. This attribute is not required, though there is no default value,
    #                and can be safely set to an empty byte array to not stop until 'count' results are seen. Otherwise, it
    #                must also be a value value to the ColumnFamily Comparator.
    # @param reversed. Whether the results should be ordered in reversed order. Similar to ORDER BY blah DESC in SQL.
    # @param count. How many keys to return. Similar to LIMIT 100 in SQL. May be arbitrarily large, but Thrift will
    #               materialize the whole result into memory before returning it to the client, so be aware that you may
    #               be better served by iterating through slices by passing the last value of one call in as the 'start'
    #               of the next instead of increasing 'count' arbitrarily large.
    class SliceRange
      include ::Thrift::Struct
      START = 1
      FINISH = 2
      REVERSED = 3
      COUNT = 4

      ::Thrift::Struct.field_accessor self, :start, :finish, :reversed, :count
      FIELDS = {
        START => {:type => ::Thrift::Types::STRING, :name => 'start'},
        FINISH => {:type => ::Thrift::Types::STRING, :name => 'finish'},
        REVERSED => {:type => ::Thrift::Types::BOOL, :name => 'reversed', :default => false},
        COUNT => {:type => ::Thrift::Types::I32, :name => 'count', :default => 100}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field start is unset!') unless @start
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field finish is unset!') unless @finish
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field reversed is unset!') if @reversed.nil?
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field count is unset!') unless @count
      end

    end

    # A SlicePredicate is similar to a mathematic predicate (see http://en.wikipedia.org/wiki/Predicate_(mathematical_logic)),
    # which is described as "a property that the elements of a set have in common."
    #
    # SlicePredicate's in Cassandra are described with either a list of column_names or a SliceRange.  If column_names is
    # specified, slice_range is ignored.
    #
    # @param column_name. A list of column names to retrieve. This can be used similar to Memcached's "multi-get" feature
    #                     to fetch N known column names. For instance, if you know you wish to fetch columns 'Joe', 'Jack',
    #                     and 'Jim' you can pass those column names as a list to fetch all three at once.
    # @param slice_range. A SliceRange describing how to range, order, and/or limit the slice.
    class SlicePredicate
      include ::Thrift::Struct
      COLUMN_NAMES = 1
      SLICE_RANGE = 2

      ::Thrift::Struct.field_accessor self, :column_names, :slice_range
      FIELDS = {
        COLUMN_NAMES => {:type => ::Thrift::Types::LIST, :name => 'column_names', :element => {:type => ::Thrift::Types::STRING}, :optional => true},
        SLICE_RANGE => {:type => ::Thrift::Types::STRUCT, :name => 'slice_range', :class => SliceRange, :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
      end

    end

    # The semantics of start keys and tokens are slightly different.
    # Keys are start-inclusive; tokens are start-exclusive.  Token
    # ranges may also wrap -- that is, the end token may be less
    # than the start one.  Thus, a range from keyX to keyX is a
    # one-element range, but a range from tokenY to tokenY is the
    # full ring.
    class KeyRange
      include ::Thrift::Struct
      START_KEY = 1
      END_KEY = 2
      START_TOKEN = 3
      END_TOKEN = 4
      COUNT = 5

      ::Thrift::Struct.field_accessor self, :start_key, :end_key, :start_token, :end_token, :count
      FIELDS = {
        START_KEY => {:type => ::Thrift::Types::STRING, :name => 'start_key', :optional => true},
        END_KEY => {:type => ::Thrift::Types::STRING, :name => 'end_key', :optional => true},
        START_TOKEN => {:type => ::Thrift::Types::STRING, :name => 'start_token', :optional => true},
        END_TOKEN => {:type => ::Thrift::Types::STRING, :name => 'end_token', :optional => true},
        COUNT => {:type => ::Thrift::Types::I32, :name => 'count', :default => 100}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field count is unset!') unless @count
      end

    end

    # A KeySlice is key followed by the data it maps to. A collection of KeySlice is returned by the get_range_slice operation.
    #
    # @param key. a row key
    # @param columns. List of data represented by the key. Typically, the list is pared down to only the columns specified by
    #                 a SlicePredicate.
    class KeySlice
      include ::Thrift::Struct
      KEY = 1
      COLUMNS = 2

      ::Thrift::Struct.field_accessor self, :key, :columns
      FIELDS = {
        KEY => {:type => ::Thrift::Types::STRING, :name => 'key'},
        COLUMNS => {:type => ::Thrift::Types::LIST, :name => 'columns', :element => {:type => ::Thrift::Types::STRUCT, :class => ColumnOrSuperColumn}}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field key is unset!') unless @key
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field columns is unset!') unless @columns
      end

    end

    class Deletion
      include ::Thrift::Struct
      TIMESTAMP = 1
      SUPER_COLUMN = 2
      PREDICATE = 3

      ::Thrift::Struct.field_accessor self, :timestamp, :super_column, :predicate
      FIELDS = {
        TIMESTAMP => {:type => ::Thrift::Types::I64, :name => 'timestamp'},
        SUPER_COLUMN => {:type => ::Thrift::Types::STRING, :name => 'super_column', :optional => true},
        PREDICATE => {:type => ::Thrift::Types::STRUCT, :name => 'predicate', :class => SlicePredicate, :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field timestamp is unset!') unless @timestamp
      end

    end

    # A Mutation is either an insert, represented by filling column_or_supercolumn, or a deletion, represented by filling the deletion attribute.
    # @param column_or_supercolumn. An insert to a column or supercolumn
    # @param deletion. A deletion of a column or supercolumn
    class Mutation
      include ::Thrift::Struct
      COLUMN_OR_SUPERCOLUMN = 1
      DELETION = 2

      ::Thrift::Struct.field_accessor self, :column_or_supercolumn, :deletion
      FIELDS = {
        COLUMN_OR_SUPERCOLUMN => {:type => ::Thrift::Types::STRUCT, :name => 'column_or_supercolumn', :class => ColumnOrSuperColumn, :optional => true},
        DELETION => {:type => ::Thrift::Types::STRUCT, :name => 'deletion', :class => Deletion, :optional => true}
      }

      def struct_fields; FIELDS; end

      def validate
      end
    end

    class TokenRange
      include ::Thrift::Struct
      START_TOKEN = 1
      END_TOKEN = 2
      ENDPOINTS = 3

      ::Thrift::Struct.field_accessor self, :start_token, :end_token, :endpoints
      FIELDS = {
        START_TOKEN => {:type => ::Thrift::Types::STRING, :name => 'start_token'},
        END_TOKEN => {:type => ::Thrift::Types::STRING, :name => 'end_token'},
        ENDPOINTS => {:type => ::Thrift::Types::LIST, :name => 'endpoints', :element => {:type => ::Thrift::Types::STRING}}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field start_token is unset!') unless @start_token
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field end_token is unset!') unless @end_token
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field endpoints is unset!') unless @endpoints
      end
    end

    # Authentication requests can contain any data, dependent on the AuthenticationBackend used
    class AuthenticationRequest
      include ::Thrift::Struct
      CREDENTIALS = 1

      ::Thrift::Struct.field_accessor self, :credentials
      FIELDS = {
        CREDENTIALS => {:type => ::Thrift::Types::MAP, :name => 'credentials', :key => {:type => ::Thrift::Types::STRING}, :value => {:type => ::Thrift::Types::STRING}}
      }

      def struct_fields; FIELDS; end

      def validate
        raise ::Thrift::ProtocolException.new(::Thrift::ProtocolException::UNKNOWN, 'Required field credentials is unset!') unless @credentials
      end
    end
  end
end