require "test_helper"

class TraceTest < Minitest::Spec
  Circuit = Trailblazer::Circuit
  Wrapped = Trailblazer::Circuit::Activity::Wrapped

  MyNested = ->(direction, options, flow_options) do
    B.__call__("start here", options,
      flow_options.merge(
        debug: B["__activity__"].circuit.instance_variable_get(:@name),
        # step_runners: ..
      )
    )

    [ direction, options, flow_options ]
  end

  class Create < Trailblazer::Operation
    step ->(options, **) { options[:a] = true }, name: "Create.task.a"
    step [ MyNested, {} ],                       name: "MyNested"
    step ->(options, **) { options[:c] = true }, name: "Create.task.c"
  end

  class B < Trailblazer::Operation
    step ->(options, **) { options[:b] = true }, name: "B.task.b"
    step ->(options, **) { options[:e] = true }, name: "B.task.e"
  end

  let (:with_tracing) do
    model_pipe = Circuit::Activity::Before( Wrapped::Activity, Wrapped::Call, Circuit::Trace.method(:capture_args), direction: Circuit::Right )
    model_pipe = Circuit::Activity::Before( model_pipe, Wrapped::Activity[:End], Circuit::Trace.method(:capture_return), direction: Circuit::Right )
  end
  it do
    step_runners = {
        nil   => with_tracing,
      }

    direction, options, flow_options = Create.__call__(
      "nil fixme start signal",
      options={},

      runner: Trailblazer::Circuit::Activity::Wrapped::Runner,
      stack:  Trailblazer::Circuit::Trace::Stack.new,
      step_runners: step_runners,
      debug:  Create["__activity__"].circuit.instance_variable_get(:@name)
    )

    puts output = Circuit::Trace::Present.tree(flow_options[:stack].to_a)

    output.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- Create.task.a
|-- #<Proc:.rb:7 (lambda)>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- B.task.b
|   |-- B.task.e
|   |-- #<Trailblazer::Operation::Railway::End::Success:>
|   `-- #<Proc:.rb:7 (lambda)>
|-- Create.task.c
`-- #<Trailblazer::Operation::Railway::End::Success:>}
  end
end