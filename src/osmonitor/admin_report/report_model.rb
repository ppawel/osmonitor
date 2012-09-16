module OSMonitor
module AdminReport

class BoundaryStatus < OSMonitor::Status
  def validate
    add_error('no_relation') if !@entity.relation

    if @entity.relation
      add_info('last_update')
      add_error('boundary_not_closed') if !@entity.closed
      add_error('boundary_admin_level') if !correct_admin_level?
      add_warning('boundary_teryt') if !correct_teryt_id?
      add_warning('boundary_ways_with_admin_level') if !ways_with_admin_level.empty?
    end
  end

  def correct_admin_level?
    @entity.relation.tags['admin_level'] == @entity.input['admin_level']
  end

  def correct_teryt_id?
    @entity.relation.tags['admin_level'] == '2' or @entity.relation.tags['teryt:terc'] == @entity.input['id']
  end

  def ways_with_admin_level
    # Ignore country admin_level for now until it is discussed more.
    @entity.ways.select {|way| way.tags.has_key?('admin_level') and way.tags['admin_level'] != '2'}
  end
end

class AdminReport < OSMonitor::Report
end

end
end
