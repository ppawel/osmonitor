#!/usr/bin/ruby

require 'net/http'
require 'erb'
require 'pg'
require 'media_wiki'
require './osm'
require './pg_db'

#mw = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
#puts mw.get "User:Ppawel/RaportDrogi"
#exit

def run_report
  @conn = PGconn.open( :host => "localhost", :dbname => 'osmdb', :user => "postgres" )
#puts cont(297112, @conn)
#return
  sql=<<-EOF
select *
from ref_relations rr
left join relations r on (
  r.tags -> 'type' = rr.type and
  r.tags -> 'route' = rr.route and
  (not r.tags ? 'network' or r.tags -> 'network' != 'BAB') and
  (r.tags -> 'ref' ilike rr.ref or replace(r.tags -> 'ref', ' ', '') ilike rr.ref))
where module = 'poland_mainroads'
order by rr.id
    EOF

  @report = []
  
  @conn.query(sql).each do |row|
    #puts row
    if row['tags']
      row['tags'] = eval("{" + row['tags'] + "}")
    end
    add_cont_to_row(row, @conn)
    @report << row
    #puts "#{row["name"]} #{row["cont_ok"]}"
  end

  data = Net::HTTP.get(URI.parse('http://pl.wikipedia.org/wiki/Drogi_krajowe_w_Polsce'))

  @krajowe_numery = data.to_s.scan(/Droga krajowa nr (\d+)/).uniq.map { |x| x[0].to_i }.sort

  sql=<<-EOF
select *
from relations
where
  tags -> 'type' = 'route' and
  tags -> 'route' = 'road' and
  (tags -> 'name' ilike '%krajowa%')
    EOF

    @krajowe = {}
    @conn.query(sql).each do |row|
      row['tags'] = eval("{" + row['tags'] + "}")
      if row['tags'].include?'name'
        @krajowe[name_to_nr_krajowy(row['tags']['name'])] = row
      end
#      add_cont_to_row(row, @conn)
      if row['tags'].include?'name'
        puts "#{row["tags"]["name"]} #{row["cont_ok"]}"
      end
    end

    template = ERB.new File.read("erb/poland_roads.erb")
    puts template.result
  end

  def add_cont_to_row(row, conn)
    components, visited = cont(row["id"], @conn)
    row["cont_ok"] = components == 1
    row["cont_comp"] = components
  end

  def cont(relation_id, conn)
    return false if ! relation_id

    @nodes = {}

    conn.transaction do |dbconn|
      dbconn.query("
SELECT distinct wn.node_id AS id
FROM relation_members rm
INNER JOIN way_nodes wn ON (wn.way_id = rm.member_id AND rm.relation_id = #{relation_id})
--INNER JOIN nodes n ON (n.id = wn.node_id)
      ").each do |row|
        row["tags"] = "'a'=>2"
        @nodes[row["id"].to_i] = OSM::Node[[0,0], row]
      
      end

      dbconn.query("
SELECT DISTINCT n.*
FROM relation_members rm
INNER JOIN way_nodes wn ON (wn.way_id = rm.member_id AND rm.relation_id = #{relation_id})
INNER JOIN node_neighs n ON (n.node_id = wn.node_id)
ORDER BY n.node_id
      ").each do |row|
        @nodes[row["node_id"].to_i].neighs << row["neigh_id"].to_i
      end
    end

    return bfs(@nodes)
  end
  
  def bfs(nodes, start_node = nil)
    return {} if nodes.empty?
    visited = {}
    i = 0

    #puts nodes

    while (visited.size < nodes.size)
      #puts "#{visited.size} <? #{nodes.size}"
      i += 1

      if i == 1 and start_node
        next_root = start_node
      else
        candidates = (nodes.keys - visited.keys)
        next_root = candidates[0]
        c = 0

        while ! nodes.include?(next_root)
          c += 1
          next_root = [c]
        end
      end
      
      visited[next_root] = i
      queue = [next_root]
      
      #puts "------------------ INCREASING i to #{i}, next_root = #{next_root}"
    

    while(!queue.empty?)
      node = queue.pop()
      #puts "visiting #{node}"
      #puts nodes[node]
      nodes[node].neighs.each do |neigh|
        #puts "neigh #{neigh} visited - #{visited.has_key?(neigh)}"
        if ! visited.has_key?(neigh) and nodes.include?(neigh) then
           queue.push(neigh)
           visited[neigh] = i
         end
      end
    end
    
    end

    return i, visited
  end

  def name_to_nr_krajowy(name)
    return name.scan(/(\d+)/)[0][0].to_i
  end

run_report
