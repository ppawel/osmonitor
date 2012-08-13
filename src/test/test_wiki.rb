$:.unshift '../' + File.dirname(__FILE__)

require "test/unit"
require "wiki"

class WikiTest < Test::Unit::TestCase
  def test_create
    page = WikiPage.new(File.read("test_wiki_page.txt"))
    assert_equal(1, page.tables.size)
    page = WikiPage.new(File.read("test_wiki_page2.txt"))
    assert_equal(3, page.tables.size)
  end
 
  def test_add_column_header
    page = WikiPage.new(File.read("test_wiki_page.txt"))
    assert(!page.page_text.include?("abc"))
    page.tables[0].add_column_header("abc")
    assert(page.page_text.include?("abc"))
    page.tables[0].add_column_header("abc")
    assert_equal(2, page.page_text.scan(/abc/m).size)
  end
  
  def test_add_column_header_2_tables
    page = WikiPage.new(File.read("test_wiki_page2.txt"))
    assert(!page.page_text.include?("abc"))

    page.tables[0].add_column_header("abc")
    assert_equal(1, page.page_text.scan(/abc/m).size)

    page.tables[0].add_column_header("abc")
    assert_equal(2, page.page_text.scan(/abc/m).size)

    page.tables[1].add_column_header("abc")
    assert_equal(3, page.page_text.scan(/abc/m).size)

    page.tables[0].add_column_header("def")
    assert_equal(3, page.page_text.scan(/abc/m).size)
    assert_equal(1, page.page_text.scan(/def/m).size)
  end

  def test_add_column_cell
    page = WikiPage.new(File.read("test_wiki_page2.txt"))
    assert(!page.page_text.include?("abc"))

    page.tables[0].add_column_header("abc")
    assert_equal(1, page.page_text.scan(/abc/m).size)

    page.tables[0].add_cell("somecell")
    assert_equal(page.tables[0].rows.size, page.page_text.scan(/somecell/m).size)

    page.tables[1].add_column_header("abc")
    assert_equal(2, page.page_text.scan(/abc/m).size)

    page.tables[0].add_column_header("def")
    assert_equal(2, page.page_text.scan(/abc/m).size)
    assert_equal(1, page.page_text.scan(/def/m).size)
  end

  def test_set_background_color
    page = WikiPage.new(File.read("test_wiki_page.txt"))
    assert(page.page_text.include?("676767"))
    assert(!page.page_text.include?("EFEFEF"))
    assert(page.page_text.include?("Legnica"))

    page.tables[0].rows[0].set_background_color("yellow")
    assert(!page.page_text.include?("676767"))
    assert(page.page_text.include?(":yellow"))

    page.tables[0].rows.each do |row|
      row.set_background_color("REDREDRED")
    end

    assert(page.page_text.include?("Legnica"))
    assert_equal(page.tables[0].rows.size, page.page_text.scan(/REDREDRED/m).size)
  end

  def test_remove_style
    page = WikiPage.new(File.read("test_wiki_page2.txt"))

    page.tables[0].rows[0].set_background_color("yellow")
    assert(page.page_text.include?("yellow"))

    page.tables[1].rows[2].set_background_color("REDRED")
    assert(page.page_text.include?("yellow"))
    assert(page.page_text.include?("REDRED"))

    page.tables[0].rows[0].remove_style
    assert(!page.page_text.include?("yellow"))
    assert(page.page_text.include?("REDRED"))

    page.tables[1].rows[2].remove_style
    assert(!page.page_text.include?("yellow"))
    assert(!page.page_text.include?("REDRED"))
  end

  def test_replace_empty_cell_text
    page = WikiPage.new(File.read("test_wiki_page3.txt"))
    assert_equal(1, page.tables.size)
    assert_equal(1, page.tables[0].rows.size)

    page.tables[0].rows.each do |row|
      assert_equal(5, row.cells.size)
    end

    page.tables[0].rows[0].cells[0].update_text('test cell 0 text row 0')
    page.tables[0].rows[0].cells[1].update_text('test cell 1 text row 0')
    page.tables[0].rows[0].cells[2].update_text('test cell 2 text row 0')
    page.tables[0].rows[0].cells[3].update_text('test cell 3 text row 0')
    page.tables[0].rows[0].cells[4].update_text('test cell 4 text row 0')
#puts page.page_text
    (0..4).each do |i|
      assert_equal(1, page.page_text.scan(/test cell #{i} text row 0/m).size, "No row 0 cell #{i} text")
      assert_equal(1, page.tables[0].rows[0].cells[i].cell_text.scan(/test cell #{i} text row 0/m).size, "No row 0 cell #{i} text")
    end

puts page.page_text
    page = WikiPage.new(page.page_text)
    assert_equal(1, page.tables.size)
    assert_equal(1, page.tables[0].rows.size)

    page.tables[0].rows.each do |row|
      assert_equal(5, row.cells.size)
    end

    (0..4).each do |i|
      assert_equal(1, page.page_text.scan(/test cell #{i} text row 0/m).size, "No row 0 cell #{i} text")
      assert_equal(1, page.tables[0].rows[0].cells[i].cell_text.scan(/test cell #{i} text row 0/m).size, "No row 0 cell #{i} text")
    end
  end
end
