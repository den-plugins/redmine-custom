class AccountingType < Enumeration
  unloadable
  has_many :issues, :foreign_key => 'acctg_type'
  has_many :projects, :foreign_key => 'acctg_type'

  OptionName = :enumeration_acctg_types

  def issue_count
    issues.count
  end

  def project_count
    projects.count
  end

  def transfer_relations(to)
    send(to.pluralize.downcase.to_sym).update_all("acctg_type = #{to.id}")
  end
end