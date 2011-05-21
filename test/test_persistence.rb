require 'helper'
require 'minitest/autorun'

class TestPersistence < MiniTest::Unit::TestCase
  def test_insert_update_remove
    Person.collection.drop

    p = Person.new

    assert !p.valid?
    assert_equal(["name can't be empty"], p.errors.full_messages)

    p["name"] = "Ben Myles"
    p["birth_year"] = 1984
    p["created_at"] = Time.now.utc
    p["admin"] = true

    assert !p.update

    assert p.insert.is_a?(BSON::ObjectId)

    assert_equal 1, Person.collection.count

    cursor = Person.find({"_id" => p["_id"]})
    found  = cursor.next
    assert_equal p, found
    assert_equal "Ben Myles", found["name"]

    p["name"] = "Benjamin"
    assert p.update

    cursor = Person.find({"_id" => p["_id"]})
    found  = cursor.next
    assert_equal p, found
    assert_equal "Benjamin", found["name"]

    assert p.remove
    assert p.removed?
    cursor = Person.find({"_id" => p["_id"]})
    found  = cursor.next
    assert_nil found
  end

  def test_save
    Person.collection.drop

    p = Person.new
    assert !p.valid?
    assert_equal(["name can't be empty"], p.errors.full_messages)

    p["name"] = "Ben Myles"
    p["birth_year"] = 1984
    p["created_at"] = Time.now.utc
    p["admin"] = true

    assert p.save.is_a?(BSON::ObjectId)
    assert_equal 1, Person.collection.count

    cursor = Person.find({"_id" => p["_id"]})
    found  = cursor.next
    assert_equal p, found
    assert_equal "Ben Myles", found["name"]

    p["name"] = "Benjamin"
    assert p.save

    assert_equal 1, Person.collection.count

    cursor = Person.find({"_id" => p["_id"]})
    found  = cursor.next
    assert_equal p, found
    assert_equal "Benjamin", found["name"]
  end

end