class Jtl::DataSet
  include Enumerable
  extend Forwardable

  def_delegators :@jtl, :scale_marks, :labels

  def self.create(data_set, jtl)
    obj = self.new(data_set, jtl)

    if block_given?
      obj.to_a.map {|i| yield(i) }
    else
      obj
    end
  end

  def initialize(data_set, jtl)
    @data_set = data_set
    @jtl = jtl
  end

  def to_hash
    hash = {}

    @data_set.each do |mark, values|
      if values.kind_of?(Jtl::LabeledValue)
        hash[values.label] ||= []
        hash[values.label] << [mark, values.value]
      else
        values.each do |lv|
          hash[lv.label] ||= {}
          hash[lv.label][mark] ||= []
          hash[lv.label][mark] << lv.value
        end
      end
    end

    return hash
  end
  alias inspect to_hash

  def [](label, &block)
    new_data_set = @data_set.first[1].kind_of?(Jtl::LabeledValue) ? [] : OrderedHash.new

    @data_set.each do |mark, values|
      if values.kind_of?(Jtl::LabeledValue)
        if (label.kind_of?(Regexp) and values.label =~ label) or values.label == label.to_s
          new_data_set << [mark, values]
        end
      else
        new_data_set[mark] = values.select do |lv|
          if label.kind_of?(Regexp)
            lv.label =~ label
          else
            lv.label == label.to_s
          end
        end
      end
    end

    self.class.create(new_data_set, @jtl, &block)
  end

  def each
    @data_set.each do |mark, values|
      if values.kind_of?(Jtl::LabeledValue)
        yield(values.value)
      else
        yield(values.map {|lv| lv.value})
      end
    end
  end

  def method_missing(name, *args, &block)
    if (ary = self.to_a).respond_to?(name)
      ary.send(name, *args, &block)
    elsif args.empty?
      self[name.to_s, &block]
    else
      super
    end
  end
end
