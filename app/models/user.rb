class User < ApplicationRecord
  has_many :attendances, dependent: :destroy
  # 「remember_token」という仮想の属性を作成し、user.remember_tokenメソッドを使えるよう実装します。
  attr_accessor :remember_token  
  before_save { self.email = email.downcase } # bofore_save コールバックメソッド
  
  validates :name,  presence: true, length: { maximum: 50 }
  
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 100 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: true
  validates :affiliation, length: { in: 2..30 }, allow_blank: true
  validates :employee_number, length: { maximum: 50 }, allow_blank: true
  validates :basic_work_time, presence: true
  has_secure_password # パスワードをハッシュ化するために bcrypt が必要
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
  
  # 渡された文字列のハッシュ値を返します。
  def User.digest(string)
    cost = 
      if ActiveModel::SecurePassword.min_cost
        BCrypt::Engine::MIN_COST
      else
        BCrypt::Engine.cost
      end
    BCrypt::Password.create(string, cost: cost)
  end

  # ランダムなトークンを返します。
  def User.new_token
    SecureRandom.urlsafe_base64
  end
  
  # 事前に remember_tokenという仮想属性を作成し、こちらで永続セッションのためハッシュ化したトークンをデータベースに記憶します。
  def remember
    self.remember_token = User.new_token # selfを記述することで仮想のremember_token属性にUser.new_tokenで生成した「ハッシュ化されたトークン情報」を代入しています。
    update_attribute(:remember_digest, User.digest(remember_token)) # update_attribute（末尾sなし）メソッドを使ってトークンダイジェストを更新しています。
  end

  # トークンがダイジェストと一致すればtrueを返します(has_secure_passwordのauthenticateの役割を持つようなメソッドのトークン版)
  def authenticated?(remember_token)
    # ダイジェストが存在しない場合はfalseを返して終了します。
    return false if remember_digest.nil?
    BCrypt::Password.new(remember_digest).is_password?(remember_token)
  end
  
  # ユーザーのログイン情報を破棄します。
  def forget
    update_attribute(:remember_digest, nil)
  end
  
  # importメソッド
  def self.import(file)
    CSV.foreach(file.path, headers: true, skip_blanks: true, encoding: 'Shift_JIS:UTF-8') do |row|
      # IDが見つかれば、レコードを呼び出し、見つかれなければ、新しく作成
      user = find_by(id: row["id"]) || new
      # CSVからデータを取得し、設定する
      user.attributes = row.to_hash.slice(*updatable_attributes)
      user.save
    end
  end
  # def self.import(file)
  #   CSV.foreach(file.path, headers: true, encoding: 'Shift_JIS:UTF-8') do |row|
  #   # IDが見つかれば、レコードを呼び出し、見つかれなければ、新しく作成
  #   user = find_by(id: row["id"]) || new
  #   # CSVからデータを取得し、設定する
  #   user.attributes = row.to_hash.slice(*updatable_attributes)
  #   user.save!(validate: false)
  #   end
  # end
  
  
  # 更新を許可するカラムを定義
  def self.updatable_attributes
    ["name", "email", "affiliation", "employee_number", "uid", "password",
    "basic_work_time", "designated_work_start_time", "designated_work_end_time",
    "superior", "admin"]
  end
end