require "test/unit"
require "./wiki"

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

  def test_add_column_cell
    page = WikiPage.new(File.read("test_wiki_page.txt"))
    assert(page.page_text.include?("676767"))
    assert(!page.page_text.include?("EFEFEF"))

    page.tables[0].rows[0].set_background_color("yellow")
    assert(!page.page_text.include?("676767"))
    assert(page.page_text.include?(":yellow"))
  end
end
