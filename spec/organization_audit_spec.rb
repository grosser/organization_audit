require "spec_helper"

describe OrganizationAudit do
  it "has a VERSION" do
    OrganizationAudit::VERSION.should =~ /^[\.\da-z]+$/
  end
end
