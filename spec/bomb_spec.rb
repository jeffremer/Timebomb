describe "Timebomb" do
  before :all do
    sleep ENV["SLEEP"].to_i if ENV["SLEEP"]
  end
  
  it 'should produce a result' do
    result = ENV['RESULT'] == "FAILURE" ? false : true
    true.should == result
  end
end
    