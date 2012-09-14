module OSMonitor
module AdminReport

class BoundaryStatus < OSMonitor::Status
  def validate
    add_error('no_relation') if !@entity.relation

    if @entity.relation
      add_error('boundary_not_closed') if !@entity.closed
      add_error('boundary_admin_level') if !correct_admin_level?
      add_warning('boundary_teryt') if !correct_teryt_id?
      add_info('last_update')
    end
  end

  def correct_admin_level?
    @entity.relation.tags['admin_level'] == @entity.input['admin_level']
  end

  def correct_teryt_id?
    @entity.relation.tags['teryt:terc'] == @entity.input['id']
  end
end

class AdminReport < OSMonitor::Report
end

end
end
