require 'spec_helper'

describe Travis::API::V3::Services::Repository::Find do
  let(:repo) { Travis::API::V3::Models::Repository.where(owner_name: 'svenfuchs', name: 'minimal').first }
  let(:build) { repo.builds.first }
  let(:jobs)  { Travis::API::V3::Models::Build.find(build.id).jobs }
  let(:parsed_body) { JSON.load(body) }

  describe "fetching a public repository by slug" do
    before     { get("/v3/repo/svenfuchs%2Fminimal")     }
    example    { expect(last_response).to be_ok }
    example    { expect(parsed_body['slug']).to be == 'svenfuchs/minimal' }
  end

  describe "fetching a non-existing repository by slug" do
    before     { get("/v3/repo/svenfuchs%2Fminimal1")     }
    example { expect(last_response).to be_not_found }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "public repository" do
    before     { get("/v3/repo/#{repo.id}")     }
    example    { expect(last_response).to be_ok }
    example    { expect(parsed_body).to be == {
      "@type"              => "repository",
      "@href"              => "/v3/repo/#{repo.id}",
      "@representation"    => "standard",
      "@permissions"       => {
        "read"             => true,
        "enable"           => false,
        "disable"          => false,
        "create_request"   => false},
      "id"                 =>  repo.id,
      "name"               =>  "minimal",
      "slug"               =>  "svenfuchs/minimal",
      "description"        => nil,
      "github_language"    => nil,
      "active"             => true,
      "private"            => false,
      "owner"              => {
        "id"               => repo.owner_id,
        "login"            => "svenfuchs",
        "@type"            => "user",
        "@href"            => "/v3/user/#{repo.owner_id}"},
      "last_build"         => {
        "@type"            => "build",
        "@href"            => "/v3/build/#{repo.last_build_id}",
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
          }}
    }}
  end

  describe "missing repository" do
    before  { get("/v3/repo/999999999999999")       }
    example { expect(last_response).to be_not_found }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "public repository, private API" do
    before  { Travis.config.private_api = true      }
    before  { get("/v3/repo/#{repo.id}")            }
    after   { Travis.config.private_api = false     }
    example { expect(last_response).to be_not_found }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "private repository, not authenticated" do
    before  { repo.update_attribute(:private, true)  }
    before  { get("/v3/repo/#{repo.id}")             }
    before  { repo.update_attribute(:private, false) }
    example { expect(last_response).to be_not_found  }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "private repository, private API, authenticated as user with access" do
    let(:token)   { Travis::Api::App::AccessToken.create(user: repo.owner, app_id: 1) }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                        }}
    before        { Travis::API::V3::Models::Permission.create(repository: repo, user: repo.owner, pull: true) }
    before        { repo.update_attribute(:private, true)                             }
    before        { get("/v3/repo/#{repo.id}", {}, headers)                           }
    after         { repo.update_attribute(:private, false)                            }
    example       { expect(last_response).to be_ok                                    }
    example       { expect(parsed_body).to be == {
      "@type"              => "repository",
      "@href"              => "/v3/repo/#{repo.id}",
      "@representation"    => "standard",
      "@permissions"       => {
        "read"             => true,
        "enable"           => false,
        "disable"          => false,
        "create_request"   => false},
      "id"                 =>  repo.id,
      "name"               =>  "minimal",
      "slug"               =>  "svenfuchs/minimal",
      "description"        => nil,
      "github_language"    => nil,
      "active"             => true,
      "private"            => true,
      "owner"              => {
        "id"               => repo.owner_id,
        "login"            => "svenfuchs",
        "@type"            => "user",
        "@href"            => "/v3/user/#{repo.owner_id}"},
      "last_build"         => {
        "@type"            => "build",
        "@href"            => "/v3/build/#{repo.last_build_id}",
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
          }}
    }}
  end

  describe "private repository, private API, authenticated as user without access" do
    let(:token)   { Travis::Api::App::AccessToken.create(user: User.find(2), app_id: 1) }
    let(:headers) {{ 'HTTP_AUTHORIZATION' => "token #{token}"                          }}
    before        { repo.update_attribute(:private, true)                               }
    before        { get("/v3/repo/#{repo.id}", {}, headers)                             }
    before        { repo.update_attribute(:private, false)                              }
    example       { expect(last_response).to be_not_found                               }
    example       { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "private repository, authenticated as internal application with full access" do
    let(:app_name)   { 'travis-example'                                                           }
    let(:app_secret) { '12345678'                                                                 }
    let(:sign_opts)  { "a=#{app_name}"                                                            }
    let(:signature)  { OpenSSL::HMAC.hexdigest('sha256', app_secret, sign_opts)                   }
    let(:headers)    {{ 'HTTP_AUTHORIZATION' => "signature #{sign_opts}:#{signature}"            }}
    before { Travis.config.applications = { app_name => { full_access: true, secret: app_secret }}}


    before { repo.update_attribute(:private, true)   }
    before { get("/v3/repo/#{repo.id}", {}, headers) }
    before { repo.update_attribute(:private, false)  }


    example { expect(last_response).to be_ok   }
    example { expect(parsed_body).to be == {
      "@type"              => "repository",
      "@href"              => "/v3/repo/#{repo.id}",
      "@representation"    => "standard",
      "@permissions"       => {
        "read"             => true,
        "enable"           => true,
        "disable"          => true,
        "create_request"   => true},
      "id"                 =>  repo.id,
      "name"               =>  "minimal",
      "slug"               =>  "svenfuchs/minimal",
      "description"        => nil,
      "github_language"    => nil,
      "active"             => true,
      "private"            => true,
      "owner"              => {
        "id"               => repo.owner_id,
        "login"            => "svenfuchs",
        "@type"            => "user",
        "@href"            => "/v3/user/#{repo.owner_id}"},
      "last_build"         => {
        "@type"            => "build",
        "@href"            => "/v3/build/#{repo.last_build_id}",
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
          }}
    }}
  end

  describe "private repository, authenticated as internal application with full access, but scoped to a different org" do
    let(:app_name)   { 'travis-example'                                                           }
    let(:app_secret) { '12345678'                                                                 }
    let(:sign_opts)  { "a=#{app_name}:s=travis-pro"                                               }
    let(:signature)  { OpenSSL::HMAC.hexdigest('sha256', app_secret, sign_opts)                   }
    let(:headers)    {{ 'HTTP_AUTHORIZATION' => "signature #{sign_opts}:#{signature}"            }}
    before { Travis.config.applications = { app_name => { full_access: true, secret: app_secret }}}

    before { repo.update_attribute(:private, true)   }
    before { get("/v3/repo/#{repo.id}", {}, headers) }
    before { repo.update_attribute(:private, false)  }

    example { expect(last_response).to be_not_found }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "not_found",
      "error_message" => "repository not found (or insufficient access)",
      "resource_type" => "repository"
    }}
  end

  describe "private repository, authenticated as internal application with full access, scoped to the right org" do
    let(:app_name)   { 'travis-example'                                                           }
    let(:app_secret) { '12345678'                                                                 }
    let(:sign_opts)  { "a=#{app_name}:s=#{repo.owner_name}"                                       }
    let(:signature)  { OpenSSL::HMAC.hexdigest('sha256', app_secret, sign_opts)                   }
    let(:headers)    {{ 'HTTP_AUTHORIZATION' => "signature #{sign_opts}:#{signature}"            }}
    before { Travis.config.applications = { app_name => { full_access: true, secret: app_secret }}}


    before { repo.update_attribute(:private, true)   }
    before { get("/v3/repo/#{repo.id}", {}, headers) }
    before { repo.update_attribute(:private, false)  }


    example { expect(last_response).to be_ok   }
    example { expect(parsed_body).to be == {
      "@type"              => "repository",
      "@href"              => "/v3/repo/#{repo.id}",
      "@representation"    => "standard",
      "@permissions"       => {
        "read"             => true,
        "enable"           => true,
        "disable"          => true,
        "create_request"   => true},
      "id"                 =>  repo.id,
      "name"               =>  "minimal",
      "slug"               =>  "svenfuchs/minimal",
      "description"        => nil,
      "github_language"    => nil,
      "active"             => true,
      "private"            => true,
      "owner"              => {
        "id"               => repo.owner_id,
        "login"            => "svenfuchs",
        "@type"            => "user",
        "@href"            => "/v3/user/#{repo.owner_id}"},
      "last_build"         => {
        "@type"            => "build",
        "@href"            => "/v3/build/#{repo.last_build_id}",
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
          }}
    }}
  end

  describe "including full owner" do
    before  { get("/v3/repo/#{repo.id}?include=repository.owner") }
    example { expect(last_response).to be_ok }
    example { expect(parsed_body['owner']).to include("github_id", "is_syncing", "synced_at",
      "@type" => "user",
      "id"    => repo.owner_id,
      "login" => "svenfuchs",
    )}
  end

  describe "including full owner and full last build" do
    before  { get("/v3/repo/#{repo.id}?include=repository.owner,repository.last_build") }
    example { expect(last_response).to be_ok }
    example { expect(parsed_body['last_build']['state']).to be == 'passed' }
    example { expect(parsed_body['last_build']['repository']).to be == { "@href" => "/v3/repo/#{repo.id}" } }
    example { expect(parsed_body['owner']).to include("github_id", "is_syncing", "synced_at")}
  end

  describe "including non-existing field" do
    before  { get("/v3/repo/#{repo.id}?include=repository.owner,repository.last_build_number") }
    example { expect(last_response.status).to be == 400 }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "wrong_params",
      "error_message" => "no field \"repository.last_build_number\" to include"
    }}
  end

  describe "wrong include format" do
    before  { get("/v3/repo/#{repo.id}?include=repository.last_build.branch") }
    example { expect(last_response.status).to be == 400 }
    example { expect(parsed_body).to be == {
      "@type"         => "error",
      "error_type"    => "wrong_params",
      "error_message" => "illegal format for include parameter"
    }}
  end

  describe "including nested objects" do
    before  { get("/v3/repo/#{repo.id}?include=repository.last_build,build.branch") }
    example { expect(last_response).to be_ok }
    example { expect(parsed_body).to include("last_build") }
  end
end
