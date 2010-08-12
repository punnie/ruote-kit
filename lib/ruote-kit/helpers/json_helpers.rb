
# license is MIT, see LICENSE.txt

module RuoteKit
  module Helpers

    # Helpers for JSON rendering
    #
    module JsonHelpers

      def json(resource, *args)

        if respond_to?("json_#{resource}")
          object = send("json_#{resource}", *args)
        end

        Rufus::Json.encode({
          'links' => links(resource),
          resource.to_s => object || args.first
        })
      end

      #def json_exception(code, exception)
      #  { 'code' => code, 'exception' => { 'message' => exception.message } }
      #end

      def json_processes

        @processes.map { |p| json_process(p) }
      end

      def json_process(process=@process)

        detailed = (@process != nil)

        process.as_h(detailed).merge('links' => [
          link('processes', process.wfid, 'self'),
          link('processes', process.wfid, '#process'),
          link('expressions', process.wfid, '#process_expressions'),
          link('workitems', process.wfid, '#process_workitems'),
          link('errors', process.wfid, '#process_errors'),
          link('schedules', process.wfid, '#process_schedules')
        ])
      end

      def json_expressions

        @process.expressions.map { |e| json_expression(e) }
      end

      def json_expression(expression=@expression)

        detailed = (@expression != nil)

        links = [
          link('expressions', expression.fei.sid, 'self'),
          link('processes', expression.fei.wfid, '#process'),
          link('expressions', expression.fei.wfid, '#process_expressions')
        ]
        links << link(
          'expressions', expression.parent.fei.sid, 'parent'
        ) if expression.parent

        expression.as_h(detailed).merge('links' => links)
      end

      def json_workitems

        @workitems.map { |w| json_workitem(w) }
      end

      def json_workitem(workitem=@workitem)

        detailed = (@workitem != nil)

        links = [
          link('expressions', workitem.fei.sid, 'self'),
          link('processes', workitem.fei.wfid, '#process'),
          link('expressions', workitem.fei.wfid, '#process_expressions'),
          link('errors', workitem.fei.wfid, '#process_errors')
        ]

        workitem.as_h(detailed).merge('links' => links)
      end

      def json_errors

        @errors.collect { |e| json_error(e) }
      end

      def json_error(error=@error)

        fei = error.fei
        wfid = fei.wfid

        error.to_h.merge('links' => [
          link('errors', fei.sid, 'self'),
          link('errors', wfid, '#process_errors'),
          link('processes', wfid, '#process')
        ])
      end

      def json_participants

        @participants.collect { |pa|
          pa.as_h.merge('links' => [ link('participants', 'self') ])
        }
      end

      def json_schedules

        @schedules.each do |sched|

          owner_fei = sched.delete('owner')
          target_fei = sched.delete('target')

          sched['owner'] = owner_fei.to_h
          sched['target'] = target_fei.to_h

          sched['links'] = [
            link('expressions', owner_fei.sid, '#schedule_owner'),
            link('expressions', target_fei.sid, '#schedule_target')
          ]
        end

        @schedules
      end

      def json_http_error(err)

        { 'code' => err[0], 'message' => err[1], 'cause' => err[2].to_s }
      end

      def links(resource)

        result = [
          link('#root'),
          link('processes', '#processes'),
          link('workitems', '#workitems'),
          link('errors', '#errors'),
          link('participants', '#participants'),
          link('schedules', '#schedules'),
          link('history', '#history'),
          link(request.fullpath, 'self')
        ]

        if @skip # pagination is active

          result << link(resource.to_s, 'all')

          las = @count / settings.limit
          pre = [ 0, @skip - settings.limit ].max
          nex = [ @skip + settings.limit, las ].min

          result << link(
            resource.to_s, { :skip => 0, :limit => settings.limit }, 'first')
          result << link(
            resource.to_s, { :skip => las, :limit => settings.limit }, 'last')
          result << link(
            resource.to_s, { :skip => pre, :limit => settings.limit }, 'previous')
          result << link(
            resource.to_s, { :skip => nex, :limit => settings.limit }, 'next')
        end

        result
      end

      def link(*args)

        rel = args.pop
        query = args.last.is_a?(Hash) ? args.pop : nil

        if args.empty? or ( ! args.first.match(/^\/\_ruote/))
          args.unshift('/_ruote')
        end
        href = args.join('/')

        query = '?' + query.collect { |k, v| "#{k}=#{v}" }.join('?') if query
        href = "#{href}#{query}"

        {
          'href' => href,
          'rel' => rel.match(/^#/) ?
            "http://ruote.rubyforge.org/rels.html#{rel}" : rel
        }
      end
    end
  end
end

module Ruote

  #
  # Re-opening to provide an as_h method
  #
  class ProcessStatus

    def as_h(detailed=true)

      h = {}

      #h['expressions'] = @expressions.collect { |e| e.fei.to_h }
      #h['errors'] = @errors.collect { |e| e.to_h }

      h['type'] = 'process'
      h['detailed'] = detailed
      h['expressions'] = @expressions.size
      h['errors'] = @errors.size
      h['stored_workitems'] = @stored_workitems.size
      h['workitems'] = workitems.size

      properties = %w[
        wfid
        definition_name definition_revision
        current_tree
        launched_time
        last_active
        tags
      ]

      properties += %w[
        original_tree
        variables
      ] if detailed

      properties.each { |m|
        h[m] = self.send(m)
      }

      h
    end
  end

  #
  # Re-opening to provide an as_h method
  #
  class Workitem

    def as_h(detailed=true)

      r = {}

      r['id'] = fei.sid
      r['fei'] = fei.sid
      r['wfid'] = fei.wfid
      r['type'] = 'workitem'
      r['participant_name'] = participant_name

      r['fields'] = h.fields

      r['put_at'] = h.put_at

      r
    end
  end

  #
  # Re-opening to provide an as_h method
  #
  class ParticipantEntry

    def as_h(detailed=true)

      { 'regex' => @regex, 'classname' => @classname, 'options' => @options }
    end
  end

  module Exp

    #
    # Re-opening to provide an as_h method
    #
    class FlowExpression

      def as_h(detailed=true)

        r = {}

        r['fei'] = fei.sid
        r['parent'] = h.parent_id ? parent_id.sid : nil
        r['name'] = h.name
        r['class'] = self.class.name

        if detailed
          r['variables'] = variables
          r['applied_workitem'] = h.applied_workitem['fields']
          r['tree'] = tree
          r['original_tree'] = original_tree
          r['timeout_schedule_id'] = h.timeout_schedule_id
        end

        r
      end
    end
  end
end

