class Jtl
  attr_reader :path

  COLUMNS = [
    :time_stamp,
    :elapsed,
    :label,
    :response_code,
    :response_message,
    :thread_name,
    :data_type,
    :success,
    :bytes,
    :latency,
  ]

  def self.parse_time_stamp(ts)
    ts = ts.to_i
    msec = (ts % 1000)
    ts = ((ts - msec) / 1000).to_i
    Time.at(ts, msec * 1000)
  end

  def initialize(path, options = {})
    @options = {:interval => 1000, :sort => true}.merge(options)
    @path = path.kind_of?(File) ? path.path : path
    @jtl = CSV.read(path)
    @jtl = @jtl.sort_by {|i| i[0] } if @options[:sort]
  end

  def write(output_path)
    CSV.open(output_path, 'wb') do |csv|
      @jtl.each do |row|
        csv << row
      end
    end
  end

  def interval
    @options[:interval]
  end

  def flatten
    self.class.new(@path, @options.merge(:interval => nil))
  end

  def labels
    @jtl.inject({}) {|r, i| r[label(i)] = true; r }.keys
  end

  def scale_marks
    aggregate_rows.map {|k, v| k }
  end

  def time_stamps(&block)
    data_set = aggregate_by(:time_stamp) {|v| v.to_i }
    DataSet.create(data_set, self, &block)
  end

  def elapseds(&block)
    data_set = aggregate_by(:elapsed) {|v| v.to_i }
    DataSet.create(data_set, self, &block)
  end

  def response_codes(&block)
    data_set = aggregate_by(:response_code) {|v| v.to_i }
    DataSet.create(data_set, self, &block)
  end

  def thread_names(&block)
    data_set = aggregate_by(:thread_name)
    DataSet.create(data_set, self, &block)
  end

  def response_messages(&block)
    data_set = aggregate_by(:response_message)
    DataSet.create(data_set, self, &block)
  end

  def data_types(&block)
    data_set = aggregate_by(:data_type)
    DataSet.create(data_set, self, &block)
  end

  def successes(&block)
    data_set = aggregate_by(:success) {|v| v == 'true' }
    DataSet.create(data_set, self, &block)
  end

  def bytes(&block)
    data_set = aggregate_by(:bytes) {|v| v.to_i }
    DataSet.create(data_set, self, &block)
  end

  def latencies(&block)
    data_set = aggregate_by(:latency) {|v| v.to_i }
    DataSet.create(data_set, self, &block)
  end

  private

  def aggregate_by(column)
    idx = COLUMNS.index(column)
    aggregated = self.interval ? OrderedHash.new : []

    aggregate_rows.each do |mark, rows|
      if self.interval
        aggregated[mark] = rows.map do |row|
          value = row[idx]
          value = yield(value) if block_given?
          LabeledValue.new(label(row), value)
        end
      else
        value = rows[idx]
        value = yield(value) if block_given?
        aggregated << [mark, LabeledValue.new(label(rows), value)]
      end
    end

    return aggregated
  end

  def aggregate_rows
    aggregated = self.interval ? OrderedHash.new : []

    @jtl.each do |row|
      ts = row[0].to_i
      ts = ts - (ts % self.interval) if self.interval
      ts = self.class.parse_time_stamp(ts)

      if self.interval
        aggregated[ts] ||= []
        aggregated[ts] << row
      else
        aggregated << [ts, row]
      end
    end

    return aggregated
  end

  def label(row)
    @label_index = COLUMNS.index(:label) unless @label_index
    row[@label_index]
  end
end
