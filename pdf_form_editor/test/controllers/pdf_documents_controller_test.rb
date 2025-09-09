require "test_helper"

class PdfDocumentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pdf_documents_index_url
    assert_response :success
  end

  test "should get show" do
    get pdf_documents_show_url
    assert_response :success
  end

  test "should get new" do
    get pdf_documents_new_url
    assert_response :success
  end

  test "should get create" do
    get pdf_documents_create_url
    assert_response :success
  end

  test "should get edit" do
    get pdf_documents_edit_url
    assert_response :success
  end

  test "should get update" do
    get pdf_documents_update_url
    assert_response :success
  end

  test "should get destroy" do
    get pdf_documents_destroy_url
    assert_response :success
  end
end
