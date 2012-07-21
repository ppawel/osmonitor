require 'media_wiki'

class WikiPage
  attr_accessor :page_text
  attr_accessor :tables

  def initialize(page_text)
    self.page_text = page_text
    self.tables = parse_tables(page_text)
  end

  def update_table_text(table, new_text)
    self.page_text.gsub!(table.table_text, new_text)
  end

  private

  def parse_tables(page)
    tables = []

    page.scan(/\{\|.*?\n\|\}/im) do |table_text|
      tables << WikiTable.new(self, table_text, Regexp.last_match.begin(0))
    end

    return tables
  end
  
end

class WikiTable
  attr_accessor :table_text
  attr_accessor :page
  attr_accessor :header
  attr_accessor :rows
  attr_accessor :start_pos

  def initialize(page, table_text, start_pos)
    self.page = page
    self.table_text = table_text
    self.rows = parse_rows(table_text)
    self.start_pos = start_pos
  end

  def add_column_header(body)
    header.add_header_cell(body)
  end

  def add_cell(body)
    rows.each do |row| row.add_cell(body) end
  end

  def update_row_text(row, new_text)
    new_table = table_text.gsub(row.row_text, new_text)
    page.update_table_text(self, new_table)
    self.table_text = new_table
  end

  private
  
  def parse_rows(table_text)
    rows = []  

    r = table_text.split("|-").drop(1)

    self.header = WikiTableRow.new(self, "|-" + r[0])

    r.drop(1).each do |row|
      rows << WikiTableRow.new(self, "|-" + row)
    end

    rows[-1].row_text.gsub!(/\|\}$/, '')
    
    return rows
  end
end

class WikiTableRow
  attr_accessor :table
  attr_accessor :row_text
  attr_accessor :cells

  def initialize(table, row_text)
    self.table = table
    self.row_text = row_text
  end

  def add_header_cell(body)
    new_row = row_text + "! " + body + "\n"
    update_text(new_row)
  end

  def add_cell(body)
    new_row = row_text + "| " + body + "\n"
    update_text(new_row)
  end

  def set_background_color(color)
    if row_text.include?("background-color")
      new_row = row_text.gsub(/background-color:(#)?\w+/i, "background-color:#{color}")
    else
      new_row = row_text.gsub(/^\|\-/, "|- style=\"background-color:#{color}\"")
    end

    update_text(new_row)
  end

  def update_text(new_row)
    table.update_row_text(self, new_row)
    self.row_text = new_row
  end

  private
  
  def parse_cells(row_text)
    cells = []

    row_text.split("\n|").each do |cell_text|
      cells << WikiTableCell(self, cell_text)
    end

    return cells
  end
  

end

class WikiTableCell
  attr_accessor :row
  attr_accessor :cell_text

  def initialize(row, cell_text)
    self.row = row
    self.cell_text = cell_text
  end
end

def get_wiki_page(name)
  mw = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
  return WikiPage.new(mw.get name)
end
