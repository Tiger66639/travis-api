require 'spec_helper'

describe Travis::API::V3::Services::Owner::Repositories do
  let(:repo)  { Travis::API::V3::Models::Repository.where(owner_name: 'svenfuchs', name: 'minimal').first }
  let(:build) { repo.builds.first }
  let(:jobs)  { Travis::API::V3::Models::Build.find(build.id).jobs }

  let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1) }
  let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                        }}
  before        { Travis::API::V3::Models::Permission.create(repository: repo, user: repo.owner, pull: true) }
  before        { repo.update_attribute(:private, true)                             }
  after         { repo.update_attribute(:private, false)                            }

  describe "private repository, private API, authenticated as user with access" do
    before  { get("/v3/owner/svenfuchs/repos", {}, headers) }
    example { expect(last_response).to be_ok }
    example { expect(JSON.load(body)).to be == {
      "@type"                => "repositories",
      "@href"                => "/v3/owner/svenfuchs/repos",
      "@representation"      => "standard",
      "repositories"         => [{
        "@type"              => "repository",
        "@href"              => "/v3/repo/#{repo.id}",
        "@representation"    => "standard",
        "@permissions"       => {
          "read"             => true,
          "enable"           => false,
          "disable"          => false,
          "create_request"   => false},
        "id"                 => repo.id,
        "name"               => "minimal",
        "slug"               => "svenfuchs/minimal",
        "description"        => nil,
        "github_language"    => nil,
        "active"             => true,
        "private"            => true,
        "owner"              => {
          "@type"            => "user",
          "id"               => repo.owner_id,
          "login"            => "svenfuchs",
          "@href"            => "/v3/user/#{repo.owner_id}" },
        "last_build"         => {
          "@type"            => "build",
          "@href"            => "/v3/build/#{repo.last_build.id}",
          "id"               => repo.last_build_id,
          "number"           => "2",
          "state"            => "passed",
          "duration"         => nil,
          "started_at"       => "2010-11-12T12:30:00Z",
          "finished_at"      => "2010-11-12T12:30:20Z"},
        "default_branch"     => {
          "@type"            => "branch",
          "@href"            => "/v3/repo/#{repo.id}/branch/master",
          "@representation"  => "minimal",
          "name"             => "master",
          "last_build"       => {
            "@type"          => "build",
            "@href"          => "/v3/build/#{repo.default_branch.last_build.id}",
            "@representation"=> "minimal",
            "id"             => repo.default_branch.last_build.id,
            "number"         => "3",
            "state"          => "configured",
            "duration"       => nil,
            "event_type"     => "push",
            "previous_state" => "passed",
            "started_at"     => "2010-11-12T13:00:00Z",
            "finished_at"    => nil,
            "jobs"           => [{
              "@type"        => "job",
              "@href"        => "/v3/job/#{jobs[0].id}",
              "@representation"=>"minimal",
              "id"           => jobs[0].id},
              {
              "@type"        => "job",
              "@href"        => "/v3/job/#{jobs[1].id}",
              "@representation"=>"minimal",
              "id"           =>  jobs[1].id},
              {
              "@type"        => "job",
              "@href"        => "/v3/job/#{jobs[2].id}",
              "@representation"=>"minimal",
              "id"           => jobs[2].id},
              {
              "@type"        => "job",
              "@href"        => "/v3/job/#{jobs[3].id}",
              "@representation"=>"minimal",
              "id"           => jobs[3].id}]

            }}}]
    }}
  end

  describe "filter: private=false" do
    before  { get("/v3/repos", {"repository.private" => "false"}, headers)                           }
    example { expect(last_response)                   .to be_ok                                      }
    example { expect(JSON.load(body)['repositories']) .to be == []                                   }
    example { expect(JSON.load(body)['@href'])        .to be == "/v3/repos?repository.private=false" }
  end

  describe "filter: active=false" do
    before  { get("/v3/repos", {"repository.active" => "false"}, headers)  }
    example { expect(last_response)                   .to be_ok            }
    example { expect(JSON.load(body)['repositories']) .to be == []         }
  end
end
